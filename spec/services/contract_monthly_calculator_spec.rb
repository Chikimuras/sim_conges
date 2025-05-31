# frozen_string_literal: true

require 'rails_helper'

describe ContractMonthlyCalculator do
  let(:start_date) { Date.new(2024, 4, 15) }
  let(:end_date)   { Date.new(2024, 7, 10) }
  let(:salary)     { 1000 }
  subject { described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary) }

  it 'génère des périodes' do
    expect(subject.periods).not_to be_empty
    expect(subject.periods.first).to be_a(LeavePeriod)
  end

  it 'calcule les détails mensuels' do
    details = subject.calculate_monthly_details
    expect(details).not_to be_empty
    expect(details.first).to have_key(:month)
    expect(details.first).to have_key(:salary_due)
    expect(details.first).to have_key(:leave_10pct)
  end

  it 'calcule le salaire dû exact pour chaque mois' do
    details = subject.calculate_monthly_details
    # Avril 2024 : 16 jours sur 30
    april = details.find { |d| d[:month] == Date.new(2024, 4, 1) }
    expect(april[:salary_due]).to eq((salary * 16.0 / 30.0).round(2))
    # Mai 2024 : mois complet
    may = details.find { |d| d[:month] == Date.new(2024, 5, 1) }
    expect(may[:salary_due]).to eq(salary)
    # Juin 2024 : mois complet
    june = details.find { |d| d[:month] == Date.new(2024, 6, 1) }
    expect(june[:salary_due]).to eq(salary)
    # Juillet 2024 : 10 jours sur 31
    july = details.find { |d| d[:month] == Date.new(2024, 7, 1) }
    expect(july[:salary_due]).to eq((salary * 10.0 / 31.0).round(2))
  end

  it 'calcule la valorisation 10% exacte pour chaque mois' do
    details = subject.calculate_monthly_details
    details.each do |d|
      expect(d[:leave_10pct]).to eq((d[:salary_due] * 0.10).round(2))
    end
  end

  it 'la somme des leave_10pct mensuels correspond à la valorisation LeavePeriod' do
    details = subject.calculate_monthly_details
    total_10pct = details.sum { |d| d[:leave_10pct] }
    period_10pct = subject.periods.sum(&:value_by_10percent)
    expect(total_10pct).to be_within(0.01).of(period_10pct)
  end

  context 'contrat d’un seul jour' do
    let(:start_date) { Date.new(2024, 5, 15) }
    let(:end_date)   { Date.new(2024, 5, 15) }
    it 'calcule correctement le salaire dû et les valorisations' do
      details = subject.calculate_monthly_details
      expect(details.size).to eq(1)
      expect(details.first[:salary_due]).to eq((salary * 1.0 / 31.0).round(2))
      expect(details.first[:leave_10pct]).to eq((details.first[:salary_due] * 0.10).round(2))
    end
  end

  context 'contrat sur un mois complet' do
    let(:start_date) { Date.new(2024, 5, 1) }
    let(:end_date)   { Date.new(2024, 5, 31) }
    it 'calcule un seul mois avec salaire complet' do
      details = subject.calculate_monthly_details
      expect(details.size).to eq(1)
      expect(details.first[:salary_due]).to eq(salary)
      expect(details.first[:leave_10pct]).to eq((salary * 0.10).round(2))
    end
  end

  context 'contrat couvrant plusieurs années' do
    let(:start_date) { Date.new(2023, 12, 15) }
    let(:end_date)   { Date.new(2024, 7, 10) }
    it 'calcule bien tous les mois couverts' do
      details = subject.calculate_monthly_details
      expect(details.first[:month]).to eq(Date.new(2023, 12, 1))
      expect(details.last[:month]).to eq(Date.new(2024, 7, 1))
      expect(details.size).to eq(8)
    end
  end
end
