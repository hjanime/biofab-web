#!script/rails runner

# run like this:
#   ./script/import_bc_designs.rb data/BD_data_for_the\ paper-Web.xlsx "BD-GOI combinations"

require 'script/math_stuff.rb'

def usage
  puts "This script imports designs from an xlsx file."
  puts "Usage: "
  puts "  #{__FILE__} <excel_sheet.xlsx> <sheet_name>"
  puts " "
  puts "  Reminder: Put quotes around sheet_name if it contains spaces."
  puts " "
end

if ARGV.length != 2
  usage()
  exit
end

filepath = ARGV[0]

x = Excelx.new(filepath)
x.default_sheet = ARGV[1]

designs = []

puts "Deleting all existing bc_designs in 10 seconds: "

10.times do |i|
  sleep 1
  print '.'
  $stdout.flush
end
print "\n"

puts "Now deleting."

BcDesign.delete_all

puts "Reading designs from xls file."

max_empty_rows = 20
blank_count = 0
row = 2
while(true)

  fpu_biofab_id = x.cell(row, 2)

  if fpu_biofab_id.blank?
    blank_count += 1
    if blank_count >= max_empty_rows
      puts "max blank count reached: #{blank_count} rows in a row. stopping loop"
      break
    end
    next
  else
    blank_count = 0
  end

  design = BcDesign.new  
  design.fpu_biofab_id = x.cell(row, 2)
  design.fpu_name = x.cell(row, 3).gsub(/\s+/,'').upcase
  design.fpu_sequence = x.cell(row, 4).upcase
  design.cds_biofab_id = x.cell(row, 5)
  design.cds_name = x.cell(row, 6)
  design.cds_sequence = x.cell(row, 7).upcase
  design.plasmid_sequence = x.cell(row, 10).upcase
  design.plasmid_biofab_id = "pFAB#{x.cell(row, 11).to_i}"
  design.strain_biofab_id = "sFAB#{x.cell(row, 14).to_i}"
  design.organism_name = x.cell(row, 12)
  design.fc_average = x.cell(row, 15).to_f
  design.fc_sd = x.cell(row, 16).to_f
  design.performance = nil

  # skip the two BCDs and two MCDs with identical sequences
  if (design.fpu_name == 'BCD3') || (design.fpu_name == 'BCD4') || (design.fpu_name == 'MCD3') || (design.fpu_name == 'MCD4')
    row += 1
    next
  end

  # fix missing ATG
  if design.fpu_sequence[-3..-1] != 'ATG'
    design.fpu_sequence += 'ATG'
  end

  designs << design

  row += 1
end

plasmid_part_type = PartType.find_by_name('Plasmid')

puts "associating #{designs.length} designs with fpu, cds and plasmid parts"
count = 1
designs.each do |design|

  part = Part.find_by_biofab_id(design.fpu_biofab_id)
  raise "no 5' UTR found with: #{design.fpu_biofab_id}" if !part
  design.fpu_part_id = (part) ? part.id : nil

  part = Part.find_by_biofab_id(design.cds_biofab_id)
  raise "no CDS found with: #{design.cds_biofab_id}" if !part
  design.cds_part_id = (part) ? part.id : nil

  part = Part.find_by_biofab_id(design.plasmid_biofab_id)
  if !part
    part = Part.new
    part.biofab_id = design.plasmid_biofab_id
    part.sequence = design.plasmid_sequence
    part.part_type = plasmid_part_type
    part.save!
  elsif part.sequence.blank?
    part.sequence = design.plasmid_sequence
  end

  raise "no plasmid found with: #{design.plasmid_biofab_id}" if !part

  design.plasmid_part_id = part.id

  print '.'
  print '|' if count % 100 == 0
  print '|' if count % 1000 == 0
  $stdout.flush
  count += 1
end

puts "\ndone saving designs"

puts
puts "== saving designs =="

count = 1
designs.each do |design|

  print '.'
  print '|' if count % 100 == 0
  print '|' if count % 1000 == 0
  $stdout.flush
  design.save!
  count += 1
end



