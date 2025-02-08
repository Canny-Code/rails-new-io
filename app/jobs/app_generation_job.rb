class AppGenerationJob < ApplicationJob
  include AcidicJob::Workflow

  def perform(generated_app_id)
    @orchestrator = AppGeneration::Orchestrator.new(GeneratedApp.find(generated_app_id))

    execute_workflow(unique_by: generated_app_id) do |workflow|
      workflow.step(:create_github_repository)
      workflow.step(:generate_rails_app)
      workflow.step(:create_initial_commit)
      workflow.step(:apply_ingredients)
      workflow.step(:push_to_remote)
      workflow.step(:start_ci)
      workflow.step(:complete_generation)
    end
  rescue StandardError => e
    orchestrator&.handle_error(e)
    raise
  end

  private

  attr_reader :orchestrator

  def create_github_repository = orchestrator.create_github_repository
  def generate_rails_app = orchestrator.generate_rails_app
  def create_initial_commit = orchestrator.create_initial_commit
  def apply_ingredients = orchestrator.apply_ingredients
  def push_to_remote = orchestrator.push_to_remote
  def start_ci = orchestrator.start_ci
  def complete_generation = orchestrator.complete_generation
end
