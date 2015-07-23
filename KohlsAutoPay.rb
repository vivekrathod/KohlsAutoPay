#!/usr/local/Cellar/ruby/2.2.0/bin/ruby
require 'capybara/poltergeist'
require 'mail'

=begin
What does the script do?
Allows one to login to their Kohls account and makes payment for the
'current balance' if any is due. I'm using this script as a cron job
that runs daily, and thought it may prove useful to others.

What is needed to run the script?
Phantomjs (http://phantomjs.org/)
Capybara (https://github.com/jnicklas/capybara)
Poltergeist (https://github.com/teampoltergeist/poltergeist)
Mail (https://github.com/mikel/mail)

On my OS X, I found homebrew (http://brew.sh/) to be the easiest way
to get all these installed.

Also, please update the kohls user/pass and security questions/answers
in 'setupUserConfig' method of 'Kohls' class. Optionally, put your 
gmail user/pass if you wish to receive email report of the payments made.

What are current limitations?
1. only the 'current balance' on the account is paid
2. only Gmail is supported for sending the email for payment report
=end

class Kohls
	def initialize
		# if running as cron job make sure the PATH is correct
		ENV['PATH'] = ENV['PATH'] + ':/usr/local/bin'
		Capybara.run_server = false
		@session = Capybara::Session.new(:poltergeist)
		# you may want to change the default time to wait for response
		#Capybara.default_wait_time = 10
		setupUserConfig
	end
	
	# update these values for your specific case
	def setupUserConfig
		# put your kohls user/pass
		@kohlsUser = ""
		@kohlsPassword = ""
		# put your gmail user/pass - its used to send payment report email to the same user
		@gmailUser = ""
		@gmailPassword = ""
		
		# add security questions and answers as you've set them
		# copy the question text as is from your account setup
		@question1 = ""
		@answer1 = ""
		@question2 = ""
		@answer2 = ""
		@question3 = ""
		@answer3 = ""
		@challanges = Hash[@question1 => @answer1, @question2 => @answer2, @question3 => @answer3]
		
	end
	
	def login
		@session.visit 'https://credit.kohls.com'

		puts 'searching for login button'
		@session.within '#loginform' do
			@session.fill_in('user', :with => @kohlsUser)
			@session.fill_in('pass', :with => @kohlsPassword)
		end
		if @session.has_button?('loginAction')
			puts 'found submit button'
			@session.click_button('loginAction')
		end
		
		@questionLabel = "Security Question"
		if @session.has_text?(@questionLabel)
			#ans 1st question
			handleChallenge
			if @session.has_no_text?(@questionLabel)
				puts 'passed challenge(s)'
			else
				# kohls seems to ask 2 questions in a row sometimes
				handleChallenge
			end
		end
	end
	
	def handleChallenge
		if @session.has_text?(@question1)
			ansChallenge(@question1)
		elsif @session.has_text?(@question2)
			ansChallenge(@question2)
		elsif @session.has_text?(@question3)
			ansChallenge(@question3)
		else
			puts 'unrecognized question...'
			@session.save_and_open_screenshot
		end
	end
	
	def ansChallenge(question)
		puts "answering question about '#{question}'"
		@session.fill_in 'singleanswer', :with => @challanges[question]
		@session.click_button 'submitChallengeAnswers'
	end
	
	def gotoMakePaymentPage
		if @session.has_no_link?'Make A Payment'
			raise 'make payment link not found..'
		end
		
		puts 'found make payment link'
		@session.click_link_or_button 'Make A Payment'
	end
	
	def getCurrentBalance
		if (@session.has_no_table?('paymentAmountSection'))
			raise 'unable to find current balance'
		end
		currentBalance = @session.find(:xpath, '//*[@id="paymentAmountSection"]/tbody/tr[4]/td[4]').text
		currentBalance = currentBalance.gsub(/[^\d\.]/, '').to_f
		puts "current balance is #{currentBalance}"
		return currentBalance
	end
	
	def makeCurrentPayment
		if @session.has_field?('curBal')
			puts 'found current balance radio button'
			@session.choose 'curBal'
		end

		if @session.has_button?('Submit')
			puts 'found Submit payment button'
			@session.click_button 'Submit'
		end
		
		if @session.has_button?('PayApproveButton')
			puts 'found pay approve button'
			@session.click_button 'PayApproveButton'
		end
	end
	
	def emailScreenshot(sub, msg)
		options = { :address      => 'smtp.gmail.com',
            :port                 => 587,
            :domain               => 'gmail.com',
            :user_name            => @gmailUser,
            :password             => @gmailPassword,
            :authentication       => 'plain',
            :enable_starttls_auto => true  }

		Mail.defaults do
		  delivery_method :smtp, options
		end
		
		screenshot = 'kohls.payment.report.png'
		@session.save_screenshot screenshot
		
		email = @gmailUser
		Mail.deliver do
		  to 		email
		  from 		'KohlsAutoPay script'
	   	  subject 	sub
		  body     	msg
		  add_file 	screenshot
		end
	end
end

kohls = Kohls.new
begin
	kohls.login
	kohls.gotoMakePaymentPage
	currentBalance = kohls.getCurrentBalance
	if ( currentBalance > 0)
		kohls.makeCurrentPayment
		kohls.emailScreenshot "kohls autopayment was successfully submitted", "current balance of #{currentBalance} was paid suceessfully, screenshot attached.."
	end
rescue Exception => e
	puts 'error..' 
	puts e.message
	kohls.emailScreenshot '*** ERROR kohls payment ***', e.message + e.backtrace.inspect
end
 	


	