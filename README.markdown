
# Wordle.jl

A Julia package for the game "Wordle"

## Notes



* We constructed the dictionary of words as follows:
    - Begin with the 2019 Scrabble dictionary
    - Keep only length-5 words
    - Give each word weight = 1
    - Cross-reference against the [word-frequency list of Rachael Tatman](https://www.kaggle.com/rtatman/english-word-frequency/version/1)
        * Keep the set of 50,000 most-frequent words
        * If a Scrabble word appears in that set, bump its weight to 10.
    - The results are stored in `src/wordle_dictionary.txt`.
    - The rationale is that we want a maximal set of *possible* words, but we want to assign much higher weight to words that are actually common. (The Scrabble dictionary contains very obscure words.)


