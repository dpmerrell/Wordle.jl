module Wordle

using JSON

export rank_first_words

ALPHABET = "abcdefghijklmnopqrstuvwxyz"
CHAR_TO_IDX = Dict(char => idx for (idx, char) in enumerate(ALPHABET))
N_ALPHA = length(ALPHABET)
WORD_LEN = 5
WORDLE_WORDS_PATH = string(@__DIR__, "/wordle_words_La.json")
SCRABBLE_WORDS_PATH = string(@__DIR__, "/scrabble_words.json")

function load_words()
    
    wordle_words = JSON.parsefile(WORDLE_WORDS_PATH) 
    scrabble_words = JSON.parsefile(SCRABBLE_WORDS_PATH)

    return wordle_words, scrabble_words
end


mutable struct Constraints
    exclusions::Vector{Bool}
    inclusions::Vector{Int}
    positions::Vector{Int}
    antipositions::Matrix{Bool}
end


function Constraints()
    exclusions = zeros(Bool,N_ALPHA)
    inclusions = zeros(Int,N_ALPHA)
    positions = zeros(Int, WORD_LEN)
    antipositions = zeros(Bool, N_ALPHA, WORD_LEN)
    return Constraints(exclusions, inclusions, 
                       positions, antipositions) 
end


function Base.copy(cons::Constraints)

    return Constraints(deepcopy(cons.exclusions),
                       deepcopy(cons.inclusions),
                       deepcopy(cons.positions),
                       deepcopy(cons.antipositions)
                      )
                       
end


function get_char_counts(word::Vector{Int})
    counts = zeros(Int, N_ALPHA)
    for char in word
        counts[char] += 1
    end
    return counts
end


function str_to_vector(word::AbstractString)
    vec = zeros(Int, WORD_LEN)
    for (i,char) in enumerate(word)
        vec[i] = CHAR_TO_IDX[char]
    end
    return vec
end


function vector_to_str(word::Vector{Int})
    c_vec = Vector{Char}(undef, WORD_LEN)
    for (i,c) in enumerate(word)
        c_vec[i] = ALPHABET[c]
    end
    return string(c_vec...)
end


# Determine whether `word` satisfies
# the constraints encoded by `c`
function (cons::Constraints)(word::Vector{Int})

    for (i, char) in enumerate(word)
        # Check exclusions
        if cons.exclusions[char]
            return false
        end
        # Check antipositions
        if cons.antipositions[char,i]
            return false
        end
    end

    # Check against known positions
    for (pos, char) in enumerate(cons.positions)
        if char > 0
            if word[pos] != char
                return false
            end
        end
    end

    # Check against inclusions
    char_counts = get_char_counts(word)
    if !all(char_counts .>= cons.inclusions)
        return false
    end

    return true
end


function wordle_clues(action::Vector{Int}, truth::Vector{Int})

    clues = zeros(Int, WORD_LEN)

    truth_bag = Dict{Int,Int}()
    pm_candidate_set = Set{Int}() 

    # Check for exact matches
    for (i,a) in enumerate(action)
        if a == truth[i]
            clues[i] = 2
        else
            if haskey(truth_bag, truth[i])
                truth_bag[truth[i]] += 1
            else
                truth_bag[truth[i]] = 1
            end

            push!(pm_candidate_set, i)
        end
    end

    # Check for partial matches
    for candidate_idx in pm_candidate_set
        cand = action[candidate_idx]
        if haskey(truth_bag, cand)
            if (truth_bag[cand] > 0)
                clues[candidate_idx] = 1
                truth_bag[cand] -= 1
            end
        else
            clues[candidate_idx] = 0
        end
    end
    return clues
end


function update_constraints!(cons::Constraints, action::Vector{Int}, 
                             clues::Vector{Int})

    valid_occurrences = Dict{Int,Int}()

    for (i, (a, clue)) in enumerate(zip(action, clues))

        # The letter got blacked out -- it doesn't
        # occur anywhere in the word
        if clue == 0
            cons.exclusions[a] = true
        # The letter occurs in the word, but not in this
        # location.
        elseif clue == 1
            # Add the corresponding "antiposition"
            cons.antipositions[a,i] = true
           
            # Increment the number of *valid* occurrences
            # for this character
            if haskey(valid_occurrences, a)
                valid_occurrences[a] += 1
            else
                valid_occurrences[a] = 1
            end
        else # clue == 2
            cons.positions[i] = a 
            
            # Increment the number of *valid* occurrences
            # for this character
            if haskey(valid_occurrences, a)
                valid_occurrences[a] += 1
            else
                valid_occurrences[a] = 1
            end
        end
    end

    for (char, n) in enumerate(cons.inclusions)
        if haskey(valid_occurrences, char)
            cons.inclusions[char] = max(n, valid_occurrences[char])
        end
    end
end


function update_constraints(cons::Constraints, action::Vector{Int},
                            clues::Vector{Int})

    cons_copy = copy(cons)
    update_constraints!(cons_copy, action, clues)
    return cons_copy
end



# Selects the best action, but also mutates the constraints
# and the set of valid words.
function score_actions(constraints, valid_words,
                       action_vec)

    total_weight = length(valid_words)

    # Pre-allocate the results
    actions = Vector{String}(undef, length(action_vec))
    scores = Vector{Float64}(undef, length(action_vec))


    Threads.@threads for i=1:length(action_vec)

        action = action_vec[i]
        expected_entropy = 0.0
        for possible_truth in valid_words

            clues = wordle_clues(action, possible_truth) 
            new_constraints = update_constraints(constraints, action, clues)

            n_valid_words = 0
            for word in valid_words
                if new_constraints(word)
                    n_valid_words += 1
                end
            end
            
            expected_entropy += n_valid_words

        end
        expected_entropy /= total_weight

        action_str = vector_to_str(action)
        print_str = string(action_str, " ", expected_entropy, "\n")
        print(print_str)

        actions[i] = action_str
        scores[i] = expected_entropy
    end
    
    return actions, scores
end


function rank_first_words()

    constraints = Constraints()
    wordle_words, scrabble_words = load_words()

    wordle_words = [str_to_vector(w) for w in wordle_words]
    scrabble_words = [str_to_vector(w) for w in scrabble_words]

    actions, scores = score_actions(constraints, wordle_words,
                                    scrabble_words)


    srt_order = sortperm(scores)
    srt_actions = actions[srt_order]
    srt_scores = scores[srt_order]

    return srt_actions, srt_scores
end


end # module

