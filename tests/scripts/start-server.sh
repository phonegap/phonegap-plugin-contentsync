DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR/../archives && python -m "SimpleHTTPServer" 4321 &
