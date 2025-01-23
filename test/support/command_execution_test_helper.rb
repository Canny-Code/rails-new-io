module CommandExecutionTestHelper
  def mock_command_execution(generated_app)
    service = mock("command_execution_service")
    service.stubs(:execute).returns(true)

    CommandExecutionService.
      stubs(:new).
      with(generated_app, generated_app.command).
      returns(service)

    service
  end
end
