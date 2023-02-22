# multiprecision-arithmetic<br>
An assembly program that computes the sum of two user input 128-bit numbers using multiprecision arithmetic. The FRDM-KL05Z board from NXP is used.

![ProgramResults](https://github.com/Helena-Lynd/multiprecision-arithmetic/blob/main/program-results.png?raw=true)

## Description<br>
Many microcontrollers have a word size of only 32 bits, yet there are instances where programmers will need to sum numbers that exceeed that limitation. This program solves that problem using multiprecision arithmetic, a technique that adds numbers larger than the word size by adding the least significant words and using the carry bit in the addition of the next least significant words until addition is complete. This program only accepts valid hexadecimal characters as input, and will not sum the numbers until two valid inputs have been received.
## Getting Started<br>
### Dependencies
- A method to compile the source files into an executable (e.g. Keil uVision5)
- KL05 board connected to a terminal (e.g. PuTTY)
### Installing
- Download the source files provided to your directory of choice
```
git clone git@github.com:Helena-Lynd/multiprecision-arithmetic.git
```
- Compile the source files into an executable
  - If using an IDE, use the "Build" or "Rebuild" feature
### Executing
- Load the executable to your boards flash memory
  - If using an IDE, use the "Download" feature
- Run the program with a connected terminal window open
  - The board has a button that can be pressed to initiate the program
- When prompted, enter the 128 bit numbers to sum
  - IMPORTANT: lowercase hex letters and input less than 32 digits are not accepted as valid input
## Authors<br>
Helena Lynd
