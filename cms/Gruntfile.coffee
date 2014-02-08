JS_VENDOR = [
  'bower_components/URIjs/src/URI.js'
  'bower_components/jquery-form/jquery.form.js'
  'bower_components/jquery-ui/ui/minified/jquery-ui.min.js'
  'bower_components/jquery/jquery.min.js'
]

CSS_VENDOR = [
  'bower_components/jquery-ui/themes/smoothness/jquery-ui.min.css'
  'bower_components/reset-css/reset.css'
]

module.exports = (grunt) ->
  grunt.initConfig


    # ==========================================================================
    # = Copy                                                                   =
    # ==========================================================================

    copy:
      cssVendor:
        expand: true
        flatten: true
        src: CSS_VENDOR
        dest: 'public/css/vendor'

      jsVendor:
        expand: true
        flatten: true
        src: JS_VENDOR
        dest: 'public/js/lib/vendor'


    # ==========================================================================
    # = Watch                                                                  =
    # ==========================================================================

    watch:
      cssVendor:
        files: CSS_VENDOR
        tasks: ['copy:cssVendor']

      jsVendor:
        files: JS_VENDOR
        tasks: ['copy:jsVendor']


  # ============================================================================
  # = Load tasks                                                               =
  # ============================================================================

  npmTasks = [
    'grunt-contrib-copy'
    'grunt-contrib-watch'
  ]

  tasks =
    default: ['copy']

  for task in npmTasks
    grunt.loadNpmTasks task

  for name, subtasks of tasks
    grunt.registerTask name, subtasks

