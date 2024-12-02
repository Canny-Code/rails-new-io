require "test_helper"

class GithubCodePushJobTest < ActiveJob::TestCase
  def setup
    @user = users(:john)
  end

  test "enqueues job with correct arguments" do
    repository_name = "test-repo"
    source_path = "path/to/source"

    assert_difference -> { SolidQueue::Job.count }, 1 do
      GithubCodePushJob.perform_later(@user.id, repository_name, source_path)
    end

    job = SolidQueue::Job.last
    assert_equal "GithubCodePushJob", job.class_name
    assert_equal [ @user.id, repository_name, source_path ], job.arguments["arguments"]
  end

  test "calls GithubCodePushService with correct arguments" do
    repository_name = "test-repo"
    source_path = "path/to/source"

    service_mock = Minitest::Mock.new
    service_mock.expect(:push, true)

    GithubCodePushService.stub :new, service_mock do
      GithubCodePushJob.perform_now(@user.id, repository_name, source_path)
    end

    assert_mock service_mock
  end
end
