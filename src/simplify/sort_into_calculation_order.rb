class SortIntoCalculationOrder
  
  attr_accessor :references
  attr_accessor :current_sheet
  attr_accessor :ordered_references
  
  
  # FIXME: Probably not the best algorithm for this
  def sort(references)
    @current_sheet = []
    @ordered_references = []
    @references = references

    # First we find the references that are at the top of the tree
    references_with_counts = CountFormulaReferences.new.count(references)
    tops = []
    references_with_counts.each do |sheet, references|
      references.each do |cell, count|
        next unless count == 0
        tops << [sheet, cell]
      end
    end
    # Then we have to work through those tops
    # recursively adding the cells that they depend on
    tops.each do |ref|
      add_ordered_references_for ref
    end
    @ordered_references
  end
  
  def add_ordered_references_for(ref)
    sheet = ref.first
    cell = ref.last
    current_sheet.push(sheet)
    ast = @references[sheet][cell]
    map(ast)
    current_sheet.pop
    ordered_references << ref
  end  

  def map(ast)
    return ast unless ast.is_a?(Array)
    operator = ast[0]
    if respond_to?(operator)
      send(operator,*ast[1..-1])
    else
      ast[1..-1].each do |a|
        map(a)
      end
    end
  end
  
  def sheet_reference(sheet,reference)
    ref = [sheet, reference.last.gsub('$','')]
    return if @ordered_references.include?(ref)
    add_ordered_references_for(ref)
  end
  
  def cell(reference)
    ref = [current_sheet.last, reference.gsub('$','')]
    return if @ordered_references.include?(ref)
    add_ordered_references_for(ref)
  end
   
end
