module DummyPackage

export add, multiply, greet, reverse_string, is_even

"""
    add(a::Number, b::Number) -> Number

Add two numbers together.
"""
function add(a::Number, b::Number)
    return a + b
end

"""
    multiply(a::Number, b::Number) -> Number

Multiply two numbers together.
"""
function multiply(a::Number, b::Number)
    return a * b
end

"""
    greet(name::String) -> String

Create a greeting message for a person.
"""
function greet(name::String)
    return "Hello, $(name)!"
end

"""
    reverse_string(s::String) -> String

Reverse a string.
"""
function reverse_string(s::String)
    return String(reverse(collect(s)))
end

"""
    is_even(n::Int) -> Bool

Check if an integer is even.
"""
function is_even(n::Int)
    return n % 2 == 0
end

end # module DummyPackage
