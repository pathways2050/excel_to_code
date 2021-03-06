require_relative '../compile'
require_relative '../excel/excel_functions'
require_relative '../util'

class FormulaeCalculator
  include ExcelFunctions
  attr_accessor :original_excel_filename
end

class MapFormulaeToValues
  
  attr_accessor :original_excel_filename
  attr_accessor :replacements_made_in_the_last_pass
  
  def initialize
    @value_for_ast = MapValuesToRuby.new
    @calculator = FormulaeCalculator.new
    @replacements_made_in_the_last_pass = 0
    @cache = {}
  end

  def reset
    @cache = {}
  end

  # FIXME: Caching works in the odd edge cases of long formula
  # but I really need to find the root cause of the problem
  def map(ast)
    @calculator.original_excel_filename = original_excel_filename
    @cache[ast] ||= do_map(ast)
  end

  def do_map(ast)
    return ast unless ast.is_a?(Array)
    operator = ast[0]
    if respond_to?(operator)
      send(operator,*ast[1..-1])
    else
      [operator,*ast[1..-1].map {|a| map(a) }]
    end
  end

  def prefix(operator,argument)
    argument_value = value(map(argument))
    return [:prefix, operator, map(argument)] if argument_value == :not_a_value
    return ast_for_value(argument_value || 0) if operator == "+"
    ast_for_value(@calculator.negative(argument_value))
  end
  
  def arithmetic(left,operator,right)
    l = value(map(left))
    r = value(map(right))
    if (l != :not_a_value) && (r != :not_a_value)
      formula_value(operator.last,l,r)
    else
      [:arithmetic,map(left),operator,map(right)]
    end
  end
  
  alias :comparison :arithmetic

  def percentage(number)
    ast_for_value(value([:percentage, number]))
  end
  
  def string_join(*args)
    values = args.map { |a| value(map(a)) } # FIXME: These eval statements are really bugging me. Must find a better solution
    if values.any? { |a| a == :not_a_value }
      [:string_join,*args.map { |a| map(a) }]
    else
      ast_for_value(@calculator.string_join(*values))
    end
  end
  
  FUNCTIONS_THAT_SHOULD_NOT_BE_CONVERTED = %w{TODAY RAND RANDBETWEEN INDIRECT}
  
  def function(name,*args)
    if FUNCTIONS_THAT_SHOULD_NOT_BE_CONVERTED.include?(name)
      [:function,name,*args.map { |a| map(a) }]
    elsif respond_to?("map_#{name.downcase}")
      send("map_#{name.downcase}",*args)
    else
      values = args.map { |a| value(map(a)) }
      if values.any? { |a| a == :not_a_value }
        [:function,name,*args.map { |a| map(a) }]
      else
        formula_value(name,*values)
      end
    end
  end

  def map_count(range)
    return [:function, "COUNT", range] unless [:array, :cell, :sheet_reference].include?(range.first)
    range = array_as_values(range)
    ast_for_value(range.size * range.first.size)
  end
  
  def map_index(array,row_number,column_number = :not_specified)
    return map_index_with_only_two_arguments(array,row_number) if column_number == :not_specified

    array_mapped = map(array)
    row_as_number = value(map(row_number))
    column_as_number = value(map(column_number))

    return [:function, "INDEX", array_mapped, map(row_number), map(column_number)] if row_as_number == :not_a_value || column_as_number == :not_a_value

    array_as_values = array_as_values(array)
    return  [:function, "INDEX", array_mapped, map(row_number), map(column_number)] unless array_as_values

    result = @calculator.send(MapFormulaeToRuby::FUNCTIONS["INDEX"],array_as_values,row_as_number,column_as_number)
    result = [:number, 0] if result == [:blank]
    result = ast_for_value(result)
    result    
  end
  
  def map_index_with_only_two_arguments(array,row_number)
    array_mapped = map(array)
    row_as_number = value(map(row_number))
    return [:function, "INDEX", array_mapped, map(row_number)] if row_as_number == :not_a_value
    array_as_values = array_as_values(array)
    return  [:function, "INDEX", array_mapped, map(row_number)] unless array_as_values
    result = @calculator.send(MapFormulaeToRuby::FUNCTIONS["INDEX"],array_as_values,row_as_number)
    result = [:number, 0] if result == [:blank]
    result = ast_for_value(result)
    result
  end
  
  def array_as_values(array_mapped)
    case array_mapped.first
    when :array
      array_mapped[1..-1].map do |row|
        row[1..-1].map do |cell|
          cell
        end
      end 
    when :cell, :sheet_reference, :blank, :number, :percentage, :string, :error, :boolean_true, :boolean_false
      [[array_mapped]]
    else
      nil
    end
  end
    
  def value(ast)
    return extract_values_from_array(ast) if ast.first == :array
    return :not_a_value unless @value_for_ast.respond_to?(ast.first)
    eval(@value_for_ast.send(*ast))
  end
  
  def extract_values_from_array(ast)
    ast[1..-1].map do |row|
      row[1..-1].map do |cell|
        v = value(cell)
        return :not_a_value if v == :not_a_value
        v
      end
    end 
  end
  
  def formula_value(ast_name,*arguments)
    raise NotSupportedException.new("#{ast_name.inspect} function not recognised in #{MapFormulaeToRuby::FUNCTIONS.inspect}") unless MapFormulaeToRuby::FUNCTIONS.has_key?(ast_name)
    ast_for_value(@calculator.send(MapFormulaeToRuby::FUNCTIONS[ast_name],*arguments))
  end
  
  def ast_for_value(value)
    return value if value.is_a?(Array) && value.first.is_a?(Symbol)
    @replacements_made_in_the_last_pass += 1
    case value
    when Numeric; [:number,value.inspect]
    when true; [:boolean_true]
    when false; [:boolean_false]
    when Symbol; 
      raise NotSupportedException.new("Error #{value.inspect} not recognised") unless MapFormulaeToRuby::REVERSE_ERRORS[value.inspect]
      [:error,MapFormulaeToRuby::REVERSE_ERRORS[value.inspect]]
    when String; [:string,value]
    when Array; [:array,*value.map { |row| [:row, *row.map { |c| ast_for_value(c) }]}]
    when nil; [:blank]
    else
      raise NotSupportedException.new("Ast for #{value.inspect} of class #{value.class} not recognised")
    end
  end
  
end
