Sequel.migration do
  up do
    $stderr.puts('Converting hstore column to json')

    node_data_hstore_to_json = <<-SQL
      ALTER TABLE node_data ALTER COLUMN data TYPE json USING (hstore_to_json_loose(data)::json);
    SQL

    run 'DROP INDEX IF EXISTS node_data_data_idx'
    run node_data_hstore_to_json

  end
end
