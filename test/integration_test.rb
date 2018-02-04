require_relative '../lib/tree_pwner_cli'

class IntegrationTest
  def initialize
    @tpc = TreePwnerCli.new('clabs.alpha@gmail.com', 'clabs.bravo@gmail.com')
    run_tests
  end

  def test_google_doc
    puts "test"
  end

  private

  def run_tests
    not_inherited = false
    public_methods(not_inherited).each { |meth| self.send(meth) }
  end
end

IntegrationTest.new