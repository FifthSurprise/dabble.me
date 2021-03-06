require 'fileutils'

class ImportController < ApplicationController
  before_action :authenticate_user!
  SPLIT_AT_DATE_REGEX = /[12]{1}[90]{1}[0-9]{2}\-[0-1]{1}[0-9]{1}\-[0-3]{1}[0-9]{1}/

  def import_ohlife
  end

  def process_ohlife
    flash = import_ohlife_entries(params[:entry][:text])
    redirect_to past_entries_path
  end

  def process_ohlife_images
    tmp = params[:zip_file]
    if tmp && File.extname(tmp.original_filename).downcase == ".zip"

      #move uploaded ZIP file to /tmp/ohlife_zips
      dir = FileUtils.mkdir_p("public/ohlife_zips/#{current_user.user_key}")
      file = File.join(dir, tmp.original_filename)
      FileUtils.mv tmp.tempfile.path, file

      ImportWorker.perform_async(current_user.id, tmp.original_filename)
      flash[:notice] = "Photo Import has started. You will be emailed upon completion."
      redirect_to past_entries_path
    else
      FileUtils.rm tmp.tempfile.path if tmp
      flash[:alert] = "Only ZIP files are allowed here."
      redirect_to import_ohlife_path
    end

  end

  private

    def import_ohlife_entries(data)
      errors = []
      user = current_user

      dates = data.scan(SPLIT_AT_DATE_REGEX)
      bodies  = data.split(SPLIT_AT_DATE_REGEX)
      bodies.shift

      dates.each_with_index do |date,i|
        body = ActionController::Base.helpers.simple_format(bodies[i])
        body.gsub!(/\A(\<p\>\<\/p\>)/,"")
        body.gsub!(/(\<p\>\<\/p\>)\z/,"")
        entry = user.entries.create(:date => date, :body => body, :inspiration_id => 1)
        unless entry.save
          errors << date
        end
      end

      flash[:notice] = "Finished importing " + ActionController::Base.helpers.pluralize(dates.count,"entry")
      if errors.present?
        flash[:alert] = "<strong>"+ActionController::Base.helpers.pluralize(errors.count,"error") + " while importing:</strong>"
        errors.each do |error|
          flash[:alert] << "<br>"+error
        end
      end
    end

end