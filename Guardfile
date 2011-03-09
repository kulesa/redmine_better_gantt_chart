# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard 'coffeescript', :output => 'assets/javascripts' do
  watch(%r{assets/javascripts/.+\.coffee})
end

guard 'rspec', :version => 1, :color => true, :bundler => false do
  watch('^spec/(.*)_spec.rb')
  watch('^lib/(.*)\.rb')                              { "spec" }
  watch('^spec/spec_helper.rb')                       { "spec" }
  watch('^app/(.*)')                                  { "spec" }
  watch('init.rb') { "spec" }
end
