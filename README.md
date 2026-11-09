# OneSwarm for NixNet

This repository sets up the [OneSwarm](https://github.com/CSEMike/OneSwarm) client for [NixNet](https://github.com/birneee/nixnet).

- `app/` contains the nixified, slightly patched [OneSwarm](https://github.com/CSEMike/OneSwarm) fork
  - **Important**: To compile OneSwarm, download the correct JDK version `jdk-6u20-linux-x64.bin` from [Java Archive Downloads - Java SE 6](https://www.oracle.com/java/technologies/javase-java-archive-javase6-downloads.html) and place it at `app/jdk-6u20-linux-x64.bin`
- `testbed/` contains the [NixNet](https://github.com/birneee/nixnet) testbed
