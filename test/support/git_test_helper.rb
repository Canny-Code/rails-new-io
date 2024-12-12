module GitTestHelper
  def stub_git_operations(model)
    git = mock("git")
    git.stubs(:add)
    git.stubs(:commit)
    model.stubs(:git).returns(git)
    model.stubs(:commit!)
    model.stubs(:repo_name).returns("test-repo")
    model.stubs(:initial_git_commit)

    mock_repo = mock("git_repo")
    mock_repo.stubs(:write_model)
    GitRepo.stubs(:new).returns(mock_repo)
  end
end
