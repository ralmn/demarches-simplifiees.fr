# frozen_string_literal: true

class Cron::Datagouv::AccountByMonthJob < Cron::CronJob
  include DatagouvCronSchedulableConcern
  self.schedule_expression = "every month at 4:30"
  HEADERS = ["mois", "nb_comptes_crees_par_mois"]
  FILE_NAME = "#{HEADERS[1]}.csv"
  DATASET = '6745cdbb3aee5fa1f498d5ef'
  RESOURCE = '38195ec9-f10d-44e0-b0aa-fc954ac27c2f'

  def perform(*args)
    csv = existing_csv(DATASET, RESOURCE)

    GenerateOpenDataCsvService.save_csv_to_tmp(FILE_NAME, HEADERS, data) do |file|
      APIDatagouv::API.upload(file, DATASET)
    end
  end

  private

  def data
    [[date_last_month, User.where(created_at: 1.month.ago.all_month).count]]
  end

  def date_last_month
    Date.today.prev_month.strftime("%Y %B")
  end

  def default_csv
    CSV::Table.new([], headers: HEADERS)
  end

  def existing_csv(dataset, resource)
    url = APIDatagouv::API.existing_file_url(dataset, resource)
    return default_csv unless url

    response = Typhoeus.get(url)
    return default_csv unless response.success?

    CSV.parse(response.body, headers: true)
  end
end
