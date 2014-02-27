#!/bin/bash

HOME_BIN=$HOME/bin
PROFILE=$HOME/.profile
BASHRC=$HOME/.bashrc

WEBDEV_DIR=/var/www/dev
WEBDEV_SCRIPT=webdev-init
APACHE_USER=www-data
ME=$(whoami)
COMPOSER_PATH=/usr/local/bin/composer 

# update the installation
NEED_UPDATES=$(/usr/lib/update-notifier/apt-check 2>&1)
if [ "$NEED_UPDATES" == "0;0" ]
then
	sudo apt-get update
	sudo apt-get upgrade
fi

# download useful packages
sudo apt-get install mc
sudo apt-get install phpmyadmin
sudo apt-get install imagemagick
sudo apt-get install git

# create a ssh key
if [ ! -f .ssh/id_rsa ] 
then
	ssh-keygen -b 4096
fi

# set umask 
if [ -f "$PROFILE" ]
then
	sed -i 's/^#umask 022$/umask 002/g' $PROFILE
fi

# set color prompt
if [ -f "$BASHRC" ]
then
	sed -i 's/^#force_color_prompt=yes$/force_color_prompt=yes/g' $BASHRC
fi

# create the $HOME/bin directory if it not exists
if [ ! -d "$HOME_BIN" ]
then
	mkdir $HOME_BIN
fi

# create the web-dev-init script
if [ ! -f "$WEBDEV_SCRIPT" ]
then
	cat << EOF > $HOME_BIN/$WEBDEV_SCRIPT
#!/bin/bash
umask 002
newgrp www-data
exit 0
EOF
fi

# add write permissions to scripts in $HOME_BIN 
chmod +x $HOME_BIN/*

# add group www-data
sudo usermod -G $APACHE_USER -a $ME

# set web environment
if [ ! -d "$WEBDEV_DIR" ]
then
	sudo mkdir $WEBDEV_DIR
fi
sudo chmod -R g+w $WEBDEV_DIR
sudo chown -R $ME:$APACHE_USER $WEBDEV_DIR

# configure apache to use clean URL in Drupal. REF: http://drupal.org/node/134439
apachectl -M | grep rewrite
if [ $? -ne 0 ]
	sudo a2enmod rewrite
	sudo service apache2 restart
fi
# change the Allowoverride None option for /var/www
sudo sed  -i '/Directory \/var\/www/ {n;n; /AllowOverride None/ {s/AllowOverride None/AllowOverride All/}}' /etc/apache2/sites-available/default
sudo apache2 reload

# download and install composer globally
if [ ! -f "$COMPOSER_PATH" ]
then
	curl -sS https://getcomposer.org/installer | php
	sudo mv composer.phar $COMPOSER_PATH
	if [ -z "$(grep export PATH="$HOME/.composer/vendor/bin:$PATH")" ]
	then
		echo "" >> $BASHRC
		echo "# add composer vendor script paths to PATH" >> $BASHRC
		echo "export PATH=\"$HOME/.composer/vendor/bin:$PATH\"" >> $BASHRC
	fi	
fi

# install drush. REF: https://github.com/drush-ops/drush
composer global show -i drush/drush
if [ $? -eq 0 ]
then
	composer global require drush/drush:6.*
fi

# reboot if required
if [ -f /var/rub/reboot-required ]
then
	sudo reboot
fi
