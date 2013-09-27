require_relative 'simple_extract_from_xml'

class ExtractNamedReferences < Nokogiri::XML::SAX::Document 

  attr_accessor :parsing, :input, :output, :sheet_names,  :sheet, :named_reference, :current_ref

  def self.extract(*args)
    self.new.extract(*args)
  end

  def extract(input)
    @sheet_names = []
    @input = input
    @output = Hash.new { |h, k| h[k] = {} } # Hash defaults to returning a hash for a key
    @parsing = false
    parser = Nokogiri::XML::SAX::Parser.new(self)
    parser.parse(input)
    output
  end

  def start_element(name,attributes)
    @current_ref = []
    # FIXME: Extracting sheet names here is a bit of a kludge
    if name == "sheet"
      sheet_names << attributes.assoc('name').last
    elsif name == "definedName"
      @parsing = true    
      sheet_index = attributes.assoc('localSheetId')
      @sheet = sheet_index ? sheet_names[sheet_index.last.to_i] : :workbook
      @named_reference = attributes.assoc('name').last
    end
  end

  def end_element(name)
    return unless name == "definedName"
    self.parsing = false
    @output[sheet][named_reference] = current_ref.join
  end

  def characters(string)
    return unless parsing
    current_ref.push(string)
  end

end
