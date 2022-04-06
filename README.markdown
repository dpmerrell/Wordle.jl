
# Wordle.jl

A Julia package for the game "Wordle."

See the list of ranked starter words in this [Google Sheet.](https://docs.google.com/spreadsheets/d/1VxCwKUsxloK0RRfHRUHFm4ik7QP8D7ssBddox5CaEx4/edit#gid=680850941)

A preview of the starter words:
1. roate
2. raise
3. raile
4. soare 

etc.

## Installation and basic usage

Install via Julia's `Pkg`:

`(@v1.6) pkg> add https://github.com/dpmerrell/Wordle.jl`

The package contains an interactive function `play_wordle()`, which will guide you through a game of Wordle and recommend words to you.

```
julia> using Wordle

julia> play_wordle()
Recommended starting word: roate
Enter your 5-letter guess
roate
Enter the resulting 5 clues (0=gray, 1=yellow, 2=green)
02100
```

etc.

## Math/algorithmic ideas

### Entropy minimization

The algorithm in this repository is based on the idea of _entropy minimization_.

At any point in a game of Wordle, there is a probability distribution over the set of valid words.

The object of the game is to make guesses and receive clues (constraints) that minimize the uncertainty in that probability distribution.

You win if you get the uncertainty down to zero!

Entropy is a sensible way to measure the distribution's uncertainty.

And if we assume uniform probability over every valid word, then this is equivalent to _minimizing the number of remaining valid words_.

### The algorithm

My solution isn't elegant. For each turn of the game, it does an exhaustive search for the word that minimizes _average number of remaining words_.

This consists of a nested loop: 
```python
for every possible guess:
    for every possible true answer:
        simulate how the clues constrain the remaining words;
        count the remaining words;
```

This is computationally expensive; worst case O(M * N^2), where
* M is the size of the set of possible "guesses"
* N is the size of the set of valid words.
* (notice that we can guess words that are not valid)

I enabled multithreaded parallelism for the main loop.
Make sure to specify multithreading at the command line:

`julia -t <NUMBER OF THREADS TO USE> ...`


## Notes

* We found the list of valid words in Wordle's source code:
    * https://www.powerlanguage.co.uk/wordle/main.e65ce0a5.js
* For our set of guesses, we use the set of all length-5 Scrabble words.
    * This seems to match the variable `Ta` in the source code ^^^





