FROM ubuntu:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    g++ \
    gcc \
    flex \
    bison \
    make \
    git \
    curl \
    patch \
    cmake

# Clone the repository
WORKDIR /opt
RUN git clone https://github.com/diffblue/hw-cbmc.git
WORKDIR /opt/hw-cbmc

# Initialize and update the CBMC submodule
RUN git submodule init && git submodule update

# Download minisat
RUN make -C lib/cbmc/src minisat2-download

# Build EBMC
RUN make -C src

# Set the entry point
ENTRYPOINT ["/opt/hw-cbmc/src/ebmc/ebmc"]