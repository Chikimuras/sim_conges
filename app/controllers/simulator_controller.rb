# frozen_string_literal: true

class SimulatorController < ApplicationController
  # GET "/" → shows the form
  def index
    # nothing here; just render index.html.erb
  end

  # POST "/simulate" → run the calculation and render results
  def simulate
    begin
      # Parse and validate dates and salary
      start_date = Date.parse(params[:start_date])
      end_date   = Date.parse(params[:end_date])
      salary     = BigDecimal(params[:monthly_salary].to_s)

      if end_date <= start_date
        flash.now[:alert] = "La date de fin doit être postérieure à la date de début."
        render :index and return
      end

      unless salary.between?(BigDecimal("200"), BigDecimal("1200"))
        flash.now[:alert] = "Le salaire doit être compris entre 200 € et 1200 €."
        render :index and return
      end

      # Use ContractMonthlyCalculator to build both @periods and @monthly_details
      calculator = ContractMonthlyCalculator.new(
        contract_start: start_date,
        contract_end:   end_date,
        monthly_salary: salary
      )

      @periods         = calculator.periods
      @monthly_details = calculator.calculate_monthly_details

    rescue ArgumentError
      flash.now[:alert] = "Format de date invalide."
      render :index and return
    end

    # If we reach here, @periods and @monthly_details are set,
    # and Rails will render simulate.html.erb by default.
  end
end
