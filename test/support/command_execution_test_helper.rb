module CommandExecutionTestHelper
  def mock_command_execution(generated_app)
    service = mock("command_execution_service")
    service.stubs(:execute).returns(true)

    CommandExecutionService.
      stubs(:new).
      with(generated_app, instance_of(AppGeneration::Logger)).
      returns(service)

    service
  end
end
