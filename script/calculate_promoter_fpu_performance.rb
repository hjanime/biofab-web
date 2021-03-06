#!script/rails runner

require 'script/math_stuff.rb'

def group_by_method(designs, method_name)
  
  objs = {}
  designs.each do |design|
    key = design.send(method_name)
    if !objs[key]
      objs[key] = {
        :key => key,
        :numbers => [],
        :mean => nil,
        :sd => nil,
        :normalized_mean => nil,
        :normalized_sd => nil,
        :strains => []
      }
    end
    
    objs[key][:numbers] << design.performance
    objs[key][:strains] << design.strain_biofab_id
  end
  
  max = 0
  objs.each_key do |key|
    objs[key][:mean] = objs[key][:numbers].mean
    objs[key][:sd] = objs[key][:numbers].standard_deviation
    if objs[key][:mean] > max
      max = objs[key][:mean]
    end
  end

  objs.each_key do |key|
    objs[key][:normalized_mean] = objs[key][:mean]
    objs[key][:normalized_sd] = objs[key][:sd]
  end

  objs
end

puts "== Calculating =="
puts

designs = Design.all

fpus = group_by_method(designs, :fpu_biofab_id)
promoters = group_by_method(designs, :promoter_biofab_id)

# TODO before merge, promoter-mean-center fpus and fpu-mean-center fpus

objs = fpus.merge(promoters) do |key, val1, val2|
  raise "hash merge conflict for key #{key}"
end

puts "== Saving calculated performance for parts with biofabid =="
puts

objs.each_key do |key|
  obj = objs[key]

  puts "#{obj[:key]} - #{objs[key][:numbers].length} - #{obj[:normalized_mean]} - #{obj[:normalized_sd]} - #{obj[:strains]}"

  part = Part.find_by_biofab_id(obj[:key])
  raise "Could not find part with biofab id #{obj[:key]}" if !part
  perf = PartPerformance.find_by_part_id(part.id)
  if !perf
    perf = PartPerformance.new
    perf.part_id = part.id
  end

  perf.performance = obj[:normalized_mean]
  perf.performance_sd = obj[:normalized_sd]

  perf.save!
end

puts "done saving!"
