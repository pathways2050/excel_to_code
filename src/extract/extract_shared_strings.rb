class ExtractSharedStrings < Nokogiri::XML::SAX::Document 

  attr_accessor :parsing, :input, :output, :current_string

  def self.extract(*args)
    self.new.extract(*args)
  end

  def extract(input)
    @input, @output, @current_string = input, [], []
    parsing = false
    parser = Nokogiri::XML::SAX::Parser.new(self)
    parser.parse(input)
    output
  end

  def start_element(name,attributes)
    return unless name == "si"
    self.parsing = true
    self.current_string = []
  end

  def end_element(name)
    return unless name == "si"
    self.parsing = false
    output.push current_string.join
  end

  def characters(string)
    return unless parsing
    current_string.push string
  end

end
