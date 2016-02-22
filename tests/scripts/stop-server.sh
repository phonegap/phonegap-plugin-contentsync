ps aux | grep -e "python -m SimpleHTTPServer" | grep -v grep | awk '{print "kill -1 " $2}' | sh
