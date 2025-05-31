# frozen_string_literal: true

class SimulatorController < ApplicationController
  # GET "/" → shows the form
  def index
    # nothing here; just render index.html.erb
  end

  # POST "/simulate" → run the calculation and render results
  def simulate
    # Vérification de la présence des champs
    if params[:start_date].blank? || params[:end_date].blank? || params[:monthly_salary].blank?
      flash.now[:alert] = "Tous les champs sont obligatoires."
      render :index and return
    end

    # Vérification du format des dates (YYYY-MM-DD)
    unless params[:start_date] =~ /^\d{4}-\d{2}-\d{2}$/ && params[:end_date] =~ /^\d{4}-\d{2}-\d{2}$/
      flash.now[:alert] = "Le format des dates doit être AAAA-MM-JJ."
      render :index and return
    end

    begin
      start_date = Date.parse(params[:start_date])
      end_date   = Date.parse(params[:end_date])
    rescue ArgumentError
      flash.now[:alert] = "Format de date invalide."
      render :index and return
    end

    # Vérification que la date de début est antérieure à la date de fin
    if end_date <= start_date
      flash.now[:alert] = "La date de fin doit être postérieure à la date de début."
      render :index and return
    end

    # Vérification du format du salaire
    begin
      salary = BigDecimal(params[:monthly_salary].to_s)
    rescue ArgumentError, TypeError
      flash.now[:alert] = "Le salaire doit être un nombre."
      render :index and return
    end

    if salary <= 0
      flash.now[:alert] = "Le salaire doit être un nombre positif."
      render :index and return
    end

    unless salary.between?(BigDecimal("200"), BigDecimal("1200"))
      flash.now[:alert] = "Le salaire doit être compris entre 200 € et 1200 €."
      render :index and return
    end

    calculator = ContractMonthlyCalculator.new(
      contract_start: start_date,
      contract_end:   end_date,
      monthly_salary: salary
    )

    @periods         = calculator.periods
    @monthly_details = calculator.calculate_monthly_details
  end
end
