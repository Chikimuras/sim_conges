# frozen_string_literal: true

require 'rails_helper'

describe ContractLeaveBuilder do
  let(:start_date) { Date.new(2024, 4, 15) }
  let(:end_date)   { Date.new(2025, 7, 10) }
  let(:salary)     { 1000 }

  it 'génère au moins un LeavePeriod' do
    builder = described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary)
    periods = builder.build_periods
    expect(periods).not_to be_empty
    expect(periods.first).to be_a(LeavePeriod)
  end

  it 'le premier LeavePeriod commence à la date de début du contrat' do
    builder = described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary)
    periods = builder.build_periods
    expect(periods.first.start_date).to eq(start_date)
  end

  it 'le dernier LeavePeriod se termine à la date de fin du contrat' do
    builder = described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary)
    periods = builder.build_periods
    expect(periods.last.end_date).to eq(end_date)
  end

  context 'contrat sur moins d’un an, commençant avant le 1er juin' do
    let(:start_date) { Date.new(2024, 4, 15) }
    let(:end_date)   { Date.new(2024, 5, 20) }
    it 'génère une seule période couvrant tout le contrat' do
      builder = described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary)
      periods = builder.build_periods
      expect(periods.size).to eq(1)
      expect(periods.first.start_date).to eq(start_date)
      expect(periods.first.end_date).to eq(end_date)
    end
  end

  context 'contrat sur plus d’un an, commençant avant le 1er juin' do
    let(:start_date) { Date.new(2023, 4, 15) }
    let(:end_date)   { Date.new(2025, 7, 10) }
    it 'génère plusieurs périodes, chacune bornée correctement' do
      builder = described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary)
      periods = builder.build_periods
      expect(periods.size).to be > 1
      # Première période : 15/04/2023 au 31/05/2023
      expect(periods[0].start_date).to eq(Date.new(2023, 4, 15))
      expect(periods[0].end_date).to eq(Date.new(2023, 5, 31))
      # Deuxième période : 01/06/2023 au 31/05/2024
      expect(periods[1].start_date).to eq(Date.new(2023, 6, 1))
      expect(periods[1].end_date).to eq(Date.new(2024, 5, 31))
      # Troisième période : 01/06/2024 au 31/05/2025
      expect(periods[2].start_date).to eq(Date.new(2024, 6, 1))
      expect(periods[2].end_date).to eq(Date.new(2025, 5, 31))
      # Dernière période : 01/06/2025 au 10/07/2025
      expect(periods.last.start_date).to eq(Date.new(2025, 6, 1))
      expect(periods.last.end_date).to eq(Date.new(2025, 7, 10))
    end
  end

  context 'contrat commençant le 1er juin' do
    let(:start_date) { Date.new(2024, 6, 1) }
    let(:end_date)   { Date.new(2025, 5, 31) }
    it 'génère une seule période du 01/06/2024 au 31/05/2025' do
      builder = described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary)
      periods = builder.build_periods
      expect(periods.size).to eq(1)
      expect(periods.first.start_date).to eq(start_date)
      expect(periods.first.end_date).to eq(end_date)
    end
  end

  context 'contrat d’un seul jour' do
    let(:start_date) { Date.new(2024, 7, 15) }
    let(:end_date)   { Date.new(2024, 7, 15) }
    it 'génère une seule période d’un jour' do
      builder = described_class.new(contract_start: start_date, contract_end: end_date, monthly_salary: salary)
      periods = builder.build_periods
      expect(periods.size).to eq(1)
      expect(periods.first.start_date).to eq(start_date)
      expect(periods.first.end_date).to eq(end_date)
    end
  end
end
