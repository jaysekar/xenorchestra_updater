#!/bin/bash

updateFromSource ()
{
echo Current branch $(git rev-parse --abbrev-ref HEAD)
echo Current version $(git describe --abbrev=0)
sleep 5s

if [ "$BRANCH" != "" ]; then
	#echo "Switching to branch '$BRANCH'..."
	sudo git checkout $BRANCH
fi

sudo git fetch origin -q
REMOTE=$(git rev-parse @{u})
output=$( sudo git rev-list HEAD...$REMOTE --count )
echo $output updates available

if [ $output -ne 0 ] || [ "$FORCE" = true ]; then
  echo "Updating from source..."
  sudo git pull
  sudo rm -rf dist
  cd node_modules
  find * -maxdepth 0 -name 'xo-server-*' -prune -o -exec rm -rf {} \; 
  cd ..
  sudo npm i
  sudo npm run build
  echo Updated version $(git describe --abbrev=0)
fi
}

main() {
	if [ "$EUID" -ne 0 ]; then 
		echo "Please run as root (sudo bash)"
		exit
	fi

	while getopts b:fn: opt; do
		case $opt in
			b)
				BRANCH="$OPTARG"
				FORCE=true
				
				if [ "$BRANCH" == "" ]; then
					BRANCH="stable"
				fi;;
				
			f)	FORCE=true;;

			n)
				NODE=true
				FORCE=true
				VERSION="$OPTARG"
				
				if [ "$VERSION" == "" ]; then
					VERSION="lts"
				fi;;
		esac
	done

	echo "Stopping xo-server..."
	isActive=$(systemctl is-active xo-server)
	if [ "$isActive" == "active" ]; then
	  sudo systemctl stop xo-server
	else
	  sudo pkill -f "/bin/xo-server"
	fi

	if [ "$NODE" = true ]; then
		echo "Updating Node.js to '$VERSION' version..."
		sudo n "$VERSION"
	fi
	
	echo "Checking xo-server..."
	cd /opt/xo-server
	updateFromSource

	echo "Checking xo-web..."
	cd /opt/xo-web
	updateFromSource

	sleep 5s

	if [ "$isActive" == "active" ]; then
	  echo "Restarting xo-server..."
	  sudo systemctl start xo-server
	else
	  echo "Please manually restart xo-server"
	fi
}

main "$@"
