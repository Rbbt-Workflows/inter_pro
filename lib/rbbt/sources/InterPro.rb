require 'rbbt-util'
require 'rbbt/sources/organism'

module InterPro
  extend Resource
  self.subdir = "share/databases/InterPro"

  InterPro.claim InterPro['.source'].protein2ipr, :url, "ftp://ftp.ebi.ac.uk/pub/databases/interpro/protein2ipr.dat.gz"

  %w(Hsa Mmu Rno).each do |organism|
    codes = Organism.organism_codes(organism)
    codes.each do |code|
      InterPro.claim InterPro[code].protein_domains, :proc do
        uniprot_colum = TSV::Parser.new(Organism.protein_identifiers(code).open).all_fields.index("UniProt/SwissProt Accession")
        uniprots = CMD.cmd("grep -v  '^#'|cut -f #{uniprot_colum+1}", :in => Organism.protein_identifiers(code).open).read.split("\n").collect{|l| l.split("|")}.flatten.uniq.reject{|l| l.empty?}

        tsv = nil
        TmpFile.with_file(uniprots * "\n") do |tmpfile|
          tsv = TSV.open(CMD.cmd("cut -f 1,2,5,6 |grep -w -F -f #{ tmpfile }| sort -u ", :in => InterPro['.source'].protein2ipr.open, :pipe => true), :merge => true, :type => :double, :monitor => true)
        end

        tsv.key_field = "UniProt/SwissProt Accession"
        tsv.fields = ["InterPro ID", "Domain Start AA", "Domain End AA"]
        tsv.to_s
      end
    end
  end

  InterPro.claim InterPro.protein_domains, :proc do |filename|
    organism = "Hsa/feb2014"
    source = InterPro[organism].protein_domains.produce.find
    Open.link source, filename
    nil
  end

  InterPro.claim InterPro.domain_names, :proc do
    tsv = TSV.open(CMD.cmd("cut -f 2,3 | sort -u", :in => InterPro['.source'].protein2ipr.open, :pipe => true), :merge => true, :type => :single)
 
    tsv.key_field = "InterPro ID"
    tsv.fields = ["Domain Name"]
    tsv.to_s
  end

  def self.name_index
    @@name_index ||= InterPro.domain_names.tsv(:persist => true, :unnamed => true)
  end

  def self.gene_index
    @@gene_index ||= InterPro.protein_domains.tsv(:persist => true, :key_field => "InterPro ID", :fields => ["UniProt/SwissProt Accession"], :type => :flat, :merge => true, :unnamed => true)
  end

  def self.domain_index
    @@domain_index          ||= InterPro.protein_domains.tsv(:persist => true, :unnamed => true, :key_field => "UniProt/SwissProt Accession", :fields => ["InterPro ID"], :merge => true)
  end

  def self.domain_position_index
    @@domain_position_index ||= InterPro.protein_domains.tsv(:persist => true, :unnamed => true, :key_field => "UniProt/SwissProt Accession", :fields => ["InterPro ID", "Domain Start AA", "Domain End AA"], :type => :double, :merge => true)
  end

  def self.ens2uniprot(organism)
    @@ens2uniprot_index ||= {}
    @@ens2uniprot_index[organism] ||= Organism.protein_identifiers(organism).tsv(:persist => true, :unnamed => true, :fields => ["UniProt/SwissProt Accession"], :key_field => "Ensembl Protein ID", :type => :flat, :merge => true)
  end

end
