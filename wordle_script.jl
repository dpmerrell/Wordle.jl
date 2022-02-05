
using Wordle

function main()
  
    actions, scores = rank_first_words()

    open("sorted_start_words.txt", "w") do f
        for (a, s) in zip(actions, scores)
            write(f, string(a, " ", s, "\n"))
        end
    end

end

main()


