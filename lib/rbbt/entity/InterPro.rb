require 'rbbt/entity'

module InterProDomain
  extend Entity
  self.format = "InterPro ID"

  self.annotation :organism
  property :description => :array2single do
    InterPro.name_index.values_at *self
  end

  property :name => :array2single do
    InterPro.name_index.values_at *self
  end

  property :proteins => :array2single do
    InterPro.gene_index.values_at(*self).
      collect{|genes| genes = genes.uniq;  genes.organism = organism if genes.respond_to? :organism; genes }.tap{|o| Protein.setup(o, "UniProt/SwissProt Accession", organism)}
  end

  property :genes => :array2single do
    InterPro.gene_index.values_at(*self).
      collect{|genes| genes = [] if genes.nil?; genes = genes.uniq;  genes.organism = organism if genes.respond_to? :organism; genes }.tap{|o| Gene.setup(o, "UniProt/SwissProt Accession", organism)}
  end
end

module MutatedIsoform
  extend Entity

  property :affected_interpro_domains => :single do
    if protein.nil? or position.nil?
      []
    else
      InterProDomain.setup(Misc.zip_fields(protein.interpro_domain_positions || []).select{|d,s,e|
        e.to_i > position and s.to_i < position
      }.collect{|d,s,e| d }, organism)
    end
  end

  property :affected_interpro_domain_positions => :single do
    if protein.nil?
      []
    else
      Misc.zip_fields(protein.interpro_domain_positions || []).select{|d,s,e|
        e.to_i > position and s.to_i < position
      }.collect{|d,s,e| [d, position - s.to_i, s.to_i, e.to_i]}
    end
  end

  property :affected_domain_positions => :single do
    affected_interpro_domain_positions
  end

  property :affected_domains => :single do
    affected_interpro_domains
  end

  property :ablated_interpro_domains => :single do
    if protein.nil?
      []
    else
      InterProDomain.setup(Misc.zip_fields(protein.interpro_domain_positions || []).select{|d,s,e|
        e.to_i > position
      }.collect{|d,s,e| d }, organism)
    end
  end

  property :ablated_interpro_domain_positions => :single do
    if protein.nil?
      []
    else
      Misc.zip_fields(protein.interpro_domain_positions || []).select{|d,s,e|
        e.to_i > position
      }.collect{|d,s,e| [d, s.to_i, e.to_i]}
    end
  end

  property :ablated_domain_positions => :single do
    ablated_interpro_domain_positions
  end

  property :ablated_domains => :single do
    ablated_interpro_domains
  end

end

module Protein
  extend Entity 

  property :interpro_domains => :array2single do
    self.collect do |protein|
      uniprot = (InterPro.ens2uniprot(protein.organism)[protein] || []).flatten
      uniprot.empty? ? nil : 
        InterPro.domain_index.values_at(*uniprot).compact.flatten.  each{|pth| pth.organism = organism if pth.respond_to? :organism }.uniq.tap{|o| InterProDomain.setup(o, organism)}
    end
  end

  property :interpro_domain_positions => :array2single do
    self.collect do |protein|
      if protein.nil?
        [].tap{|o| InterProDomain.setup(o, organism)}
      else
        uniprot = (InterPro.ens2uniprot(protein.organism)[protein] || []).flatten
        uniprot.empty? ? nil : 
          InterPro.domain_position_index.values_at(*uniprot).compact.flatten(1).tap{|o| InterProDomain.setup(o, organism)}
      end
    end
  end
end 


