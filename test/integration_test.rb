require_relative '../lib/tree_pwner_cli'

class IntegrationTest
  def initialize
    # @tpc = TreePwnerCli.new('clabs.alpha@gmail.com', 'chrismo@clabs.org')

    # @tpc = TreePwnerCli.new('clabs.alpha@gmail.com', 'clabs.bravo@gmail.com')
    # @tpc = TreePwnerCli.new('clabs.bravo@gmail.com', 'clabs.alpha@gmail.com')
    run_tests
  end

  def test_google_doc_owner_transfer
    @tpc.open_source('test')
    @tpc.make_target_owner_of_current_folder_files
    puts @tpc.pretty_inspect
  end

  def test_cleanup_trash
    @tpc.cleanup_source_trash_found_in_target(safe_perma_delete: true)
  end

  private

  def run_tests
    not_inherited = false
    public_methods(not_inherited).each { |meth| self.send(meth) }
  end
end

IntegrationTest.new