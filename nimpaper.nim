import smtp, rss, strutils, FeedNim, times, parseopt

var
  eml = ""
  pwd = ""
  configFile = ""

for kind,key,val in getOpt():
  case kind
    of cmdArgument:
      configFile = $key
    of cmdLongOption,cmdShortOption: discard
    of cmdEnd: discard

var fullMsg = "<html><body>"

#var modPubDate = "Thu, 26 Aug 2021 15:00:00 +0000"
#modPubDate = modPubDate[0 .. ^3] & ":" & modPubDate[^2 .. ^1]
#doAssert((parse(modPubDate, "ddd, dd MMM yyyy HH:mm:ss zzz").utc - now().utc).inHours > 24)
#echo (now().utc - parse(modPubDate, "ddd, dd MMM yyyy HH:mm:ss zzz").utc).inHours

#var modPublished = "2021-08-27T02:08:26+00:00"
#modPublished = modPublished[0 .. 9] & " " & modPublished[11 .. ^1]
#modPublished.insert(" ", 19)
#echo(modPublished)
#echo (now().utc - parse(modPublished, "yyyy-MM-dd HH:mm:ss zzz").utc).inHours
#quit()

proc sendMail(fromAddr: string; toAddrs, ccAddrs: seq[string];
              subject, message, login, password: string;
              server = "smtp.gmail.com"; port = Port 465; ssl = true) =
  let msg = createMessage(subject, message, toAddrs, ccAddrs, [("Content-Type", "text/html"), ("charset","UTF-8"),("Content-Transfer-Encoding", "quoted-printable")])
  let session = newSmtp(useSsl = ssl, debug = true)
  session.connect(server, port)
  session.auth(login, password)
  session.sendMail(fromAddr, toAddrs, $msg)

proc buildFeed(feedUrl: string,itemCount: int, fullText = false , isAtom = false): string =
  var formattedMsg = ""
  try:
    if not isAtom:
      let rssFeed = rss.getRSS(feedUrl)

      var feedMsg = ""
      var totalStories = 0

      for i in 0 ..< itemCount:
        # Sometimes the amount of news is smaller than what the user sets
        try:
          # "Tue, 19 Oct 2004 13:38:55 -0400"
          var modPubDate = rssFeed.items[i].pubDate
          # if there is no publish date, skip time calculations
          if(modPubDate != ""):
            modPubDate = modPubDate[0 .. ^3] & ":" & modPubDate[^2 .. ^1]
            if (now().utc - parse(modPubDate, "ddd, dd MMM yyyy HH:mm:ss zzz").utc).inHours > 24:
              continue
          feedMsg = feedMsg & "<li><h3><a href=3D'" & rssFeed.items[i].link & "'>" & rssFeed.items[i].title & "</a></h3>"
        except:
          break
        
        #formattedMsg = formattedMsg & "<p>" & rssFeed.items[i].pubDate & "</p>"

        if fullText:
          #feedMsg = feedMsg & "<p>" & rssFeed.items[i].description.replace("href=", "href=3D").replace("<hr />","") & "</p></li>"
          feedMsg = feedMsg & "<p>" & rssFeed.items[i].description.replace("<hr />","") & "</p></li>"
        else:
          feedMsg = feedMsg & "</li>"
        
        totalStories += 1

      feedMsg = feedMsg & "</ul>"

      if(totalStories > 0):
        formattedMsg = formattedMsg & "<h2><a href=3D'" & rssFeed.link & "'>" & rssFeed.title & "</a></h2><ul>" & feedMsg

    else:
      let atomFeed = getAtom(feedUrl)

      var feedMsg = ""

      var totalStories = 0
      for i in 0 ..< itemCount:
        # Sometimes the amount of news is smaller than what the user sets
        try:
          #"2021-08-27T02:08:26+00:00"
          var modPublished = atomFeed.entries[i].published
          var dateString = ""

          # if there is no published date, skip time calculations
          if(modPublished != ""):
            # account for the published date not including time zone information
            if(len(modPublished) < 20):
              modPublished = modPublished[0 .. 9] & " " & modPublished[11 .. 18]
              dateString = "yyyy-MM-dd HH:mm:ss"
            else:
              modPublished = modPublished[0 .. 9] & " " & modPublished[11 .. ^1]
              modPublished.insert(" ", 19)
              dateString = "yyyy-MM-dd HH:mm:ss zzz"

            if (now().utc - parse(modPublished, dateString).utc).inHours > 24:
              continue

          feedMsg = feedMsg & "<li><h3><a href=3D'" & atomFeed.entries[i].link.href & "'>" & atomFeed.entries[i].title.text & "</a></h3>"
        except:
          break

        if fullText:
          #feedMsg = feedMsg & "<p>" & atomFeed.entries[i].content.text.replace("href=", "href=3D").replace("<hr />","") & "</p></li>"
          feedMsg = feedMsg & "<p>" & atomFeed.entries[i].content.text.replace("<hr />","") & "</p></li>"
        else:
          feedMsg = feedMsg & "</li>"

        totalStories += 1

      feedMsg = feedMsg & "</ul>"

      if(totalStories > 0):
        formattedMsg = formattedMsg & "<h2><a href=3D'" & atomFeed.link.href & "'>" & atomFeed.title.text & "</a></h2><ul>" & feedMsg

  except:
    formattedMsg = "<br>Error with: " & feedUrl

  return formattedMsg

proc parseCfg() =
  var
    mode = ""
  let input = open(configFile)
  for line in input.lines:
    case mode:
      of "[login]":
        if(line.startsWith("email:")):
          eml = line.split('"')[1]
        elif(line.startsWith("password:")):
          pwd = line.split('"')[1]
        else:
          mode = line
      of "[feeds]":
        if(line.startsWith("title:")):
          fullMsg = fullMsg & "<h1>" & line.split('"')[1] & "</h1>"
        else:
          var splLine = line.split(',')

          fullMsg = fullMsg & buildFeed($splLine[0].replace("\"",""),splLine[1].parseInt(),splLine[2].parseBool,splLine[3].parseBool)
            
      else:
        mode = line

parseCfg()

fullMsg = fullMsg & "</body></html>"
# Replace all the broken characters
fullMsg = strutils.multiReplace(fullMsg, [("&#8211;", "-"), ("–", "-"), ("&rsquo;", "'"), ("’", "'"), ("&lsquo;", "'"), ("‘", "'"), ("—", "-"), ("&mdash;", "-"), ("“", "\""), ("&ldquo;", "\""), ("”", "\""), ("&rdquo;", "\""), ("　", " "), ("&#12288;", " "),
                                          # TODO: Figure out a better way to do this
                                          # Mathematical Alphanumeric Symbols
                                          # Bold Symbols
                                          ("&#119808;", "A"),("𝐀", "A"),
                                          ("&#119809;", "B"),("𝐁", "B"),
                                          ("&#119810;", "C"),("𝐂", "C"),
                                          ("&#119811;", "D"),("𝐃", "D"),
                                          ("&#119812;", "E"),("𝐄", "E"),
                                          ("&#119813;", "F"),("𝐅", "F"),
                                          ("&#119814;", "G"),("𝐆", "G"),
                                          ("&#119815;", "H"),("𝐇", "H"),
                                          ("&#119816;", "I"),("𝐈", "I"),
                                          ("&#119817;", "J"),("𝐉", "J"),
                                          ("&#119818;", "K"),("𝐊", "K"),
                                          ("&#119819;", "L"),("𝐋", "L"),
                                          ("&#119820;", "M"),("𝐌", "M"),
                                          ("&#119821;", "N"),("𝐍", "N"),
                                          ("&#119822;", "O"),("𝐎", "O"),
                                          ("&#119823;", "𝐏"),("𝐏", "𝐏"),
                                          ("&#119824;", "Q"),("𝐐", "Q"),
                                          ("&#119825;", "R"),("𝐑", "R"),
                                          ("&#119826;", "S"),("𝐒", "S"),
                                          ("&#119827;", "T"),("𝐓", "T"),
                                          ("&#119828;", "U"),("𝐔", "U"),
                                          ("&#119829;", "V"),("𝐕", "V"),
                                          ("&#119830;", "W"),("𝐖", "W"),
                                          ("&#119831;", "X"),("𝐗", "X"),
                                          ("&#119832;", "Y"),("𝐘", "Y"),
                                          ("&#119833;", "Z"),("𝐙", "Z"),
                                          ("&#119834;", "a"),("𝐚", "a"),
                                          ("&#119835;", "b"),("𝐛", "b"),
                                          ("&#119836;", "c"),("𝐜", "c"),
                                          ("&#119837;", "d"),("𝐝", "d"),
                                          ("&#119838;", "e"),("𝐞", "e"),
                                          ("&#119839;", "f"),("𝐟", "f"),
                                          ("&#119840;", "g"),("𝐠", "g"),
                                          ("&#119841;", "h"),("𝐡", "h"),
                                          ("&#119842;", "i"),("𝐢", "i"),
                                          ("&#119843;", "j"),("𝐣", "j"),
                                          ("&#119844;", "k"),("𝐤", "k"),
                                          ("&#119845;", "l"),("𝐥", "l"),
                                          ("&#119846;", "m"),("𝐦", "m"),
                                          ("&#119847;", "n"),("𝐧", "n"),
                                          ("&#119848;", "o"),("𝐨", "o"),
                                          ("&#119849;", "p"),("𝐩", "p"),
                                          ("&#119850;", "q"),("𝐪", "q"),
                                          ("&#119851;", "r"),("𝐫", "r"),
                                          ("&#119852;", "s"),("𝐬", "s"),
                                          ("&#119853;", "t"),("𝐭", "t"),
                                          ("&#119854;", "u"),("𝐮", "u"),
                                          ("&#119855;", "v"),("𝐯", "v"),
                                          ("&#119856;", "w"),("𝐰", "w"),
                                          ("&#119857;", "x"),("𝐱", "x"),
                                          ("&#119858;", "y"),("𝐲", "y"),
                                          ("&#119859;", "z"),("𝐳", "z")
                                          ])

sendMail(fromAddr = eml,
        toAddrs  = @[eml],
        ccAddrs  = @[],
        subject  = "NimPaper - " & $now().weekday & " " & $now().format("MM-dd-yyyy htt"),
        message  = fullMsg,
        login    = eml,
        password = pwd)