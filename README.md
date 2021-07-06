# NimPaper
Program to send a selection of RSS/Atom feeds to your inbox. Great for cutting down on doom scrolling!

## How to Use
1. Install Nim on your target system
   - The install will vary based on your system.
   - I recommend choosenim for most systems, but on the Raspberry Pi I had to use the snap store to grab a more recent version that includes Nimble.
2. Install the RSS and FeedNim Nimble packages
   - nimble install rss
   - nimble install feednim
3. Create a new configuration file or modify the sample.cfg to setup your feeds
   - Modify the file to include your email and password that you would send your feed to.
     - I'd recommend using an app password after setting up two factor with Google.
     - For simplicity, NimPaper uses your own email to both send and receive emails.
   - Add your feeds following the given structure:
     - ["Feed Url in Quotes"],[Post Count],[Show Full Text? (true/false)],[Is Atom Feed? (true/false)]
   - You can give a selection of your feeds a title to better organize and seperate them
     - title:["Title Name in Quotes"]
4. Compile your nim code.
   - nim c nimpaper.nim
5. Run the nimpaper executable that step 4 creates with your custom configuration file as a parameter.
   - Unix Terminal: ./nimpaper "sample.cfg"
   - Windows Command Line: nimpaper.exe "sample.cfg"
6. From here you can set a cron job in Linux (.sh file) or Task Scheduler in Windows (.bat file) to automate the process
   - This is by far the trickiest step that differs from platform to platform.
   - I suggest Googling to figure this step out.
