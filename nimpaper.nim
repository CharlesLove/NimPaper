import smtp, rss, strutils, FeedNim, times, parseopt, unittest

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

#var modPubDate = "Thu, 26 Aug 2021 15:00:00 +0000";
#modPubDate = modPubDate[0 .. ^3] & ":" & modPubDate[^2 .. ^1]
#doAssert((parse(modPubDate, "ddd, dd MMM yyyy HH:mm:ss zzz").utc - now().utc).inHours > 24)
#echo (now().utc - parse(modPubDate, "ddd, dd MMM yyyy HH:mm:ss zzz").utc).inHours
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
      formattedMsg = formattedMsg & "<h2><a href=3D'" & rssFeed.link & "'>" & rssFeed.title & "</a></h2><ul>"

      for i in 0 ..< itemCount:
        # Sometimes the amount of news is smaller than what the user sets
        try:
          # "Tue, 19 Oct 2004 13:38:55 -0400"
          var modPubDate = rssFeed.items[i].pubDate;
          modPubDate = modPubDate[0 .. ^3] & ":" & modPubDate[^2 .. ^1]
          if (now().utc - parse(modPubDate, "ddd, dd MMM yyyy HH:mm:ss zzz").utc).inHours > 24:
            continue
          formattedMsg = formattedMsg & "<li><h3><a href=3D'" & rssFeed.items[i].link & "'>" & rssFeed.items[i].title & "</a></h3>"
        except:
          break
        
        #formattedMsg = formattedMsg & "<p>" & rssFeed.items[i].pubDate & "</p>"

        if fullText:
          formattedMsg = formattedMsg & "<p>" & rssFeed.items[i].description.replace("href=", "href=3D").replace("<hr />","") & "</p></li>"
        else:
          formattedMsg = formattedMsg & "</li>"

      formattedMsg = formattedMsg & "</ul>"

    else:
      let atomFeed = getAtom(feedUrl)
      formattedMsg = formattedMsg & "<h2><a href=3D'" & atomFeed.link.href & "'>" & atomFeed.title.text & "</a></h2><ul>"

      for i in 0 ..< itemCount:
        # Sometimes the amount of news is smaller than what the user sets
        try:
          formattedMsg = formattedMsg & "<li><h3><a href=3D'" & atomFeed.entries[i].link.href & "'>" & atomFeed.entries[i].title.text & "</a></h3>"
        except:
          break
        if fullText:
          formattedMsg = formattedMsg & "<p>" & atomFeed.entries[i].content.text.replace("href=", "href=3D").replace("<hr />","") & "</p></li>"
        else:
          formattedMsg = formattedMsg & "</li>"

      formattedMsg = formattedMsg & "</ul>"

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

sendMail(fromAddr = eml,
        toAddrs  = @[eml],
        ccAddrs  = @[],
        subject  = "NimPaper - " & $now().weekday & " " & $now().format("MM-dd-yyyy htt"),
        message  = fullMsg,
        login    = eml,
        password = pwd)