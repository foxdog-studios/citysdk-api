require 'sequel/model'

class Owner < Sequel::Model
  plugin :validation_helpers
  one_to_many :layers

  def validate
    super
    validates_presence [:domains, :organization, :email]
    validates_unique :email
    validates_format /^\S+@\S+\.\S+$/, :email
  end


  def validatePW(s1, s2)
    return true if s1.empty? and s2.empty? and !self.id.nil?
    if s1 == s2
      return true if s1.length > 7 and s1 =~ /\d/ and s1 =~ /[A-Z]/
      self.errors.add(:password, " needs to be > 7 chars, contain numbers and capitals")
    else
      self.errors.add(:password, " and confirmation don't match")
    end
    puts self.errors
    false
  end


  def createPW(pw)
    self.salt = Digest::MD5.hexdigest(Random.rand().to_s)
    self.passwd = Digest::MD5.hexdigest(salt+pw)
    self.save
  end

  def touch_session
    self.timeout = Time.now + 60
    self.save
  end

  def self.valid_session(auth_key)
    return false if auth_key.nil?
    owner = Owner.where(auth_key: auth_key).first
    !owner.nil?
  end

  def self.validSessionForLayer(s, l)
    o = Owner.where(session: s).first
    if(o and o.timeout and o.timeout > Time.now and Layer[l].owner_id == o.id )
      o.touch_session
      return true
    end
    nil
  end

  def self.login(email, password)
    owner = Owner.where(email: email).first

    if owner.nil?
      CSDK_CMS.do_abort(422, "Unknown email address #{ email }.")
      return
    end # if

    salt = owner.salt
    password = '' if password.nil?
    password = Digest::MD5.hexdigest(salt + password)

    unless password == owner.passwd
      CSDK_CMS.do_abort(401, 'Not authorized')
    end

    auth_key = Digest::MD5.hexdigest(salt + Random.rand().to_s)
    owner.update(auth_key: auth_key)
    [owner.id, auth_key]
  end # def
end # class

