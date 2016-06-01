require 'rbbt/workflow'
require 'rbbt/sources/organism'
require 'rbbt/sources/InterPro'

module InterPro
  extend Workflow

  input :mutated_isoforms, :array, "Mutated Isoforms", nil, :stream => true
  input :organism, :string, "Organism code", Organism.default_code("Hsa")
  task :domains => :tsv do |mis,organism|
    ens2uni = InterPro.ens2uniprot(organism)
    domain_positions = InterPro.domain_position_index
    dumper = TSV::Dumper.new :key_field => "Mutated Isoform", :fields => ["InterPro Domain", "Domain status"], :namespace => organism
    dumper.init
    TSV.traverse mis, :type => :array, :into => dumper do |mi|
      next unless mi =~ /^ENSP/
      protein, _sep, change = mi.partition(":")
      ref, position, alt = change.match(/^([A-Z*])(\d+)(.*)$/).captures
      next if ref == alt
      position = position.to_i
      uniprot = ens2uni[protein]
      next if uniprot.nil? or uniprot.empty?
      prot_domain_positions = domain_positions.values_at(*uniprot).compact
      next if prot_domain_positions.empty?
      
      domains = [] 
      statuses = []
      case
      when change =~ /[A-Z]\d+[A-Z]/
        status = "mutated"
      when change =~ /[A-Z]\d+(Frame|\*)/
        status = "ablated"
      end
      
      prot_domain_positions.each do |e| 
        Misc.zip_fields(e).each do |dom,s,e|
          next if domains.include? dom
          s = s.to_i
          e = e.to_i
          if status == 'mutated'
            next if position < s or position > e
          else
            next if position > e
          end
          domains << dom
          statuses << status
        end
      end

      [mi, [domains, statuses]]
    end
  end
end
