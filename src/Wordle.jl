module Wordle


mutable struct Constraints
    UB::Dict{Char,Int}
    LB::Dict{Char,Int}
    ordering::Vector{Char}
end


ALPHABET = "abcdefghijklmnopqrstuvwxyz"
WORD_LEN = 5


function Constraints()

    UB = Dict(ch => 5 for ch in ALPHABET)
    LB = Dict(ch => 0 for ch in ALPHABET)
    ordering = ['*' for _=1:WORD_LEN]

    return Constraints(UB, LB, ordering) 
end


function get_char_counts(word)
    counts = Dict{Char,Int}()
    for char in word
        if haskey(counts, char)
            counts[char] += 1
        else
            counts[char] = 1
        end
    end
    return counts
end


# Determine whether `word` satisfies
# the constraints encoded by `c`
function (c::Constraints)(word::String)
    # Check that the word satisfies ordering
    # constraints
    for (i, ch) in enumerate(word)
        if !in(c.ordering[i], (ch, '*'))
            return false
        end
    end

    # Check that the word satisfies character
    # count constraints
    char_counts = get_char_counts(word)
    for (ch, count) in char_counts
        if (count > c.UB[ch]) | (count < c.LB[ch])
            return false
        end
    end

    return true
end


function wordle_clues(action::String, truth::String)

    clues = zeros(Int, WORD_LEN)
    for (i,a) in enumerate(action)
        if a == truth[i]
            clues[i] = 2
        elseif a in truth
            clues[i] = 1
        end
    end
    return clues
end



function update_constraints!(c::Constraints, action::String, 
                                             clues::Vector{Int})

    for (i, (a, clue)) in enumerate(zip(action, clues))
        # The letter got blacked out -- it doesn't
        # occur anywhere in the word
        if clue == 0
            c.UB[a] = 0
            c.LB[a] = 0
        elseif clue == 1
        
        elseif clue == 2

        else

        end
    end
end



function load_dictionary(dictionary_path)
    lines = open(dictionary_path, "r") do f
        readlines(f)
    end

    pairs = [split(line) for line in lines]
    pairs = [(p[1],Int(p[2])) for p in pairs]

    weights = Dict{String,Int}(pairs)
    words = String[p[1] for p in pairs]

    return words, weights
end



end # module
