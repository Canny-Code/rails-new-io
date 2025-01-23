module CommandExecutionTestHelper
  def mock_command_execution(generated_app)
    service = mock("command_execution_service")
    service.stubs(:execute).returns(true)

    puts "DEBUG: Setting up CommandExecutionService mock"
    puts "DEBUG: Generated app command: #{generated_app.command.inspect}"

    # Stub the constructor with the expected arguments
    CommandExecutionService.stubs(:new)
      .with(generated_app, generated_app.command)
      .returns(service)

    service
  end
end
