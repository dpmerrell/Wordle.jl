module Wordle

using JSON

export rank_first_words, play_wordle

ALPHABET = "abcdefghijklmnopqrstuvwxyz"
CHAR_TO_IDX = Dict(char => idx for (idx, char) in enumerate(ALPHABET))
N_ALPHA = length(ALPHABET)
WORD_LEN = 5
WORDLE_WORDS_PATH = string(@__DIR__, "/wordle_words_La.json")
SCRABBLE_WORDS_PATH = string(@__DIR__, "/scrabble_words.json")

function load_words()
    
    wordle_words = JSON.parsefile(WORDLE_WORDS_PATH)
    wordle_words = convert(Vector{String}, wordle_words)
    scrabble_words = JSON.parsefile(SCRABBLE_WORDS_PATH)
    scrabble_words = convert(Vector{String}, scrabble_words)

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


function (cons::Constraints)(word::String)
    return cons(str_to_vector(word))
end

function (cons::Constraints)(word_vec::Vector{String})
    result = String[]
    for w in word_vec
        if cons(w)
            push!(result, w)
        end
    end
    return result
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

        # The letter occurs in the word, but not in this
        # location.
        if clue == 1
            # Add the corresponding "antiposition"
            cons.antipositions[a,i] = true
           
            # Increment the number of *valid* occurrences
            # for this character
            if haskey(valid_occurrences, a)
                valid_occurrences[a] += 1
            else
                valid_occurrences[a] = 1
            end
        # The letter occurs at this location!
        elseif clue == 2
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

    for (a, clue) in zip(action, clues)
        if (clue == 0) & !haskey(valid_occurrences, a)
        # The letter got blacked out and has no valid 
        # occurrences -- it doesn't occur anywhere in the word
            cons.exclusions[a] = true
        end
    end

    for (char, n) in valid_occurrences
        cons.inclusions[char] = max(n, cons.inclusions[char])
    end
end


function update_constraints!(cons::Constraints, action::String, clues::Vector{Int})
    action = str_to_vector(action)
    update_constraints!(cons, action, clues)
end


function update_constraints(cons::Constraints, action,
                            clues::Vector{Int})

    cons_copy = copy(cons)
    update_constraints!(cons_copy, action, clues)
    return cons_copy
end



# Selects the best action, but also mutates the constraints
# and the set of valid words.
function score_actions(constraints::Constraints, valid_words::Vector{Vector{Int}},
                       action_vec::Vector{Vector{Int}};
                       rule::String="mean", verbose::Bool=false)

    # Pre-allocate the results
    actions = Vector{String}(undef, length(action_vec))
    scores = Vector{Float64}(undef, length(action_vec))

    mean_denom = 1.0 / length(valid_words)

    Threads.@threads for i=1:length(action_vec)

        action = action_vec[i]
        
        # Reset the score
        if rule == "mean"
            action_score = 0.0
        else # "max"
            action_score = -Inf
        end

        for possible_truth in valid_words

            clues = wordle_clues(action, possible_truth) 
            new_constraints = update_constraints(constraints, action, clues)

            # Compute entropy given this (action,truth) combo
            n_valid_words = 0
            for word in valid_words
                if new_constraints(word)
                    n_valid_words += 1 
                end
            end
           
            # Update the aggregate score for this action
            if rule == "mean"
                action_score += (n_valid_words*mean_denom)
            else # "max"
                action_score = max(action_score, n_valid_words)
            end

        end

        action_str = vector_to_str(action)
        
        if verbose
            print_str = string(action_str, " ", rule ,": ", action_score, "\n")
            print(print_str)
        end

        actions[i] = action_str
        scores[i] = action_score
    end
    
    srt_order = sortperm(scores)
    srt_actions = actions[srt_order]
    srt_scores = scores[srt_order]
    
    return srt_actions, srt_scores
end


function score_actions(constraints::Constraints, valid_words::Vector{String},
                       action_vec::Vector{String}; kwargs...)
    return score_actions(constraints, Vector{Int}[str_to_vector(s) for s in valid_words],
                                      Vector{Int}[str_to_vector(s) for s in action_vec];
                                      kwargs...
                        )
end


function rank_first_words(;rule::String="mean")

    constraints = Constraints()
    wordle_words, scrabble_words = load_words()

    actions, scores = score_actions(constraints, wordle_words,
                                    scrabble_words; rule=rule)


    return actions, scores
end


function display_recs(recs, scores)
    k = length(recs)
    result = ""
    for (rec, score) in zip(recs[1:k-1], scores[1:k-1])
        result = string(result, rec, " (", score,"), ")
    end
    result = string(result, recs[k], " (", scores[k],")")

    return result
end


function display_valid_words(valid_words; top_k::Int=10)
    result = ""
    N = length(valid_words)
    if N > 10 # Print leading and trailing, with ellipsis
        result = string(join(valid_words[1:3], ", "), "... ", join(valid_words[N-2:N], ", "))
    else # Print them all
        result = join(valid_words, ", ")
    end

    return result
end


function play_wordle(;rule::String="mean", top_k::Int=10)

    constraints = Constraints()
    valid_words, scrabble_words = load_words()

    if rule == "mean"
        recommendation = "roate"
    elseif rule == "max"
        recommendation = "stare"
    end

    println(string("Recommended starting word: ", recommendation))
    for i=2:6
        println("Enter your 5-letter guess")
        action = readline()
        println("Enter the resulting 5 clues (0=gray, 1=yellow, 2=green)")
        clues_str = readline()

        clues = [parse(Int,c) for c in clues_str]

        update_constraints!(constraints, action, clues)
        valid_words = constraints(valid_words)

        if length(valid_words) == 1
            println(string("Game finished! Only one possible word: ", valid_words[1]))
            return
        elseif length(valid_words) == 0
            println("Game over! No known words satisfy your constraints :(")
            return
        else
            valid_word_str = display_valid_words(valid_words; top_k=top_k)
            println(string(length(valid_words), " remaining valid words: "))
            println(valid_word_str)
        end

        recs, scores = score_actions(constraints, valid_words,
                                     scrabble_words, rule=rule)
        recs = recs[1:top_k]
        scores = scores[1:top_k]

        rec_str = display_recs(recs,scores)
        println(string("\nRecommended guesses: ", rec_str, "..."))
    end 
    println("Ran out of guesses! Game over :(")
end


end # module

