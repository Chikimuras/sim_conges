# frozen_string_literal: true

class SimulatorController < ApplicationController
  # GET "/" → shows the form
  def index
    # nothing here; just render index.html.erb
  end

  # POST "/simulate" → run the calculation and render results
  def simulate
    validator = SimulationParamsValidator.new(params)
    unless validator.valid?
      flash.now[:alert] = validator.error
      render :index and return
    end

    calculator = ContractMonthlyCalculator.new(
      contract_start: validator.start_date,
      contract_end:   validator.end_date,
      monthly_salary: validator.salary
    )

    @periods         = calculator.periods
    @monthly_details = calculator.calculate_monthly_details
  end
end
