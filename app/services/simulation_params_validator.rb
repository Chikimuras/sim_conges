# Classe de validation des paramètres de simulation de congés.
#
# @example
#   params = { start_date: '2024-06-01', end_date: '2024-06-30', monthly_salary: '1000' }
#   validator = SimulationParamsValidator.new(params)
#   if validator.valid?
#     puts validator.start_date
#     puts validator.end_date
#     puts validator.salary
#   else
#     puts validator.error
#   end
#
# @attr_reader [Date] start_date La date de début de la simulation
# @attr_reader [Date] end_date La date de fin de la simulation
# @attr_reader [BigDecimal] salary Le salaire mensuel validé
# @attr_reader [String, nil] error Le message d'erreur en cas d'échec de validation
class SimulationParamsValidator
   attr_reader :start_date, :end_date, :salary, :error

   def initialize(params)
      @params = params
      @error = nil
   end

   def valid?
      return error!("Tous les champs sont obligatoires.") if missing_fields?
      return error!("Le format des dates doit être JJ/MM/AAAA.") unless valid_date_format?
      parse_dates
      return false if @error
      return error!("La date de fin doit être postérieure à la date de début.") if @end_date <= @start_date
      parse_salary
      return false if @error
      return error!("Le salaire doit être un nombre positif.") if @salary <= 0
      return error!("Le salaire doit être compris entre 200 € et 1200 €.") unless (BigDecimal("200")..BigDecimal("1200")).include?(@salary)
      true
   end

   private

   def missing_fields?
      @params[:start_date].blank? || @params[:end_date].blank? || @params[:monthly_salary].blank?
   end

   def valid_date_format?
      @params[:start_date] =~ /^\d{4}-\d{2}-\d{2}$/ && @params[:end_date] =~ /^\d{4}-\d{2}-\d{2}$/
   end

   def parse_dates
      @start_date = Date.parse(@params[:start_date])
      @end_date   = Date.parse(@params[:end_date])
   rescue ArgumentError
      error!("Format de date invalide.")
   end

   def parse_salary
      @salary = BigDecimal(@params[:monthly_salary].to_s)
   rescue ArgumentError, TypeError
      error!("Le salaire doit être un nombre.")
   end

   def error!(msg)
      @error = msg
      false
   end
end
