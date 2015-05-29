# KohlsAutoPay
A ruby script to make auto payments to Kohls at https://credit.kohls.com
It allows one to login to their Kohls account and make payment for the
'current balance' (if any). I'm using this script as a cron job
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
