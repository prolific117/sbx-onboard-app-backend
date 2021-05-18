class VerifyMailer < ApplicationMailer
  default from: 'olatunji.oduro@gmail.com'

  def verify_email
    @user = params[:user]
    @url  = 'https://verify-sandbox.gocardless.com'
    mail(to: @user.email, subject: 'Vefify Gocardless Account')
  end
end
