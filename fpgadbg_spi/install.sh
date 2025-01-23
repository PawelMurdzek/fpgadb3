install_package() {
    PACKAGE=$1
    if ! dpkg -s "$PACKAGE" &> /dev/null; then
        echo "Installing package $PACKAGE..."
        sudo apt-get -y install "$PACKAGE"
        if [ $? -ne 0 ]; then
            echo "Error: $PACKAGE installation failed"
            exit 1
        fi
    else
        echo "$PACKAGE is already installed."
    fi
}

sudo apt update

echo "Installing necessary packages"
install_package "build-essential"
install_package "autoconf" 
install_package "libtool"
install_package "libpcre2-dev"
install_package "bison"
install_package "libbz2-dev"
install_package "gtkwave"
install_package "gpiozero"
install_package "spidev"


echo "Installing zwig"
git clone https://github.com/swig/swig.git
cd swig
./autogen.sh
./configure
make
sudo make install
make clean
cd ../

echo "Compiling c code..."

cd fpgadbg_core
make
cd ../

echo "Compiling c code succesfull"

echo "Finished instalation"
