# multiprecision-arithmetic<br>
An assembly program that computes the sum of two user input 128-bit numbers using multiprecision arithmetic. The Keil uVision5 environment is used with FRDM-KL05Z board from NXP.

![ProgramResults](https://github.com/Helena-Lynd/multiprecision-arithmetic/blob/main/program-results.png?raw=true)

## Description<br>
The KL05 word size is only 32 bits, yet there are instances where programmers will need to sum numbers that exceeed that limitation. This program uses multiprecision arithmetic, a technique that adds numbers larger than the word size by adding the least significant words and using the carry bit in the addition of the next least significant words until addition is complete. This program only accepts valid hexadecimal characters as input, and will not sum the numbers until two valid inputs have been received.
## Getting Started<br>
### Dependencies
- A method to compile the source files into an executable (e.g. Keil uVision5)
- KL05 board connected to a terminal (e.g. PuTTY)
### Installing
- Download the source files provided to your directory of choice
- Compile the source files into an executable
### Executing
- Load the executable to your boards flash memory and run it with a connected terminal window open
- When prompted, enter the 128 bit numbers to sum
## Authors<br>
Helena Lynd
