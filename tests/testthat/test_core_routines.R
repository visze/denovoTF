# test the main script for annotating a file of de novos (denovo_TF.R)

source("../R/core.R")
library(testthat)

context("Testing core routines")

test_that("sequence_context is correct for simple set of sequences", {
  
  dn = read.table(header=TRUE, colClasses=c("character", "numeric", "character", "character"), text="
      chr pos ref alt
      chr16 85662461 C T
      chr19 32662337 A C
      chr9 26205098 T C
      chr3 180462583 T C")
  
  interval = 5
  
  seqs = get_sequence(dn$chr, dn$pos - interval, dn$pos + interval, version = "hg19")
  
  expect_equal(as.character(seqs[[1]]), "ACTCGCGCCAT") # check that the first sequence is identical to what is expected (with interval 5)
  expect_equal(substring(seqs, interval+1, interval+1), dn$ref) # ref nucleotide in de novo file should be equal to the ref nucleotide in sequence
        
})

test_that("predicted transcription factor binding sites matches expectation", {
  
  # sequence comes from: get_sequence("chr3", 180462550, 180462600) - DDD has de novo at pos 180462583
  seq = "GCTAATTCCACTATTTCTTCTCTTTTAATGAGATGAGCCTGTCCTCATCTT"
  rel_pos = 180462583 - 180462550 + 1  # relative position of de novo in sequence
  pos_hits = single_sequence_coverage(seq, rel_pos, pwm_list, min.score = "95%")
  
  expect_equal(names(pos_hits), "MA0036.1")
  expect_equal(pos_hits[[1]]@pattern@name, "GATA2")
  
})

test_that("change in score for de novo binding matches expectation", {
  
  seq = "ATTTCTTCTCTTTTAATGAGATGAGCCTGTCCTCATCTTTTTC"
  pos_hits = single_sequence_coverage(seq, 22, pwm_list)
  ss = pos_hits[[1]]
  ref = "T"
  alt = "C"
  
  ref_alt = binding_change(ss, 22, ref, alt, min.score = "95%")
  
  expect_equal(ref_alt[1], 5.931088, tolerance = 0.01)
  expect_equal(ref_alt[2], -2.124195, tolerance = 0.01)
  
  
})

test_that("single de novo hits same TFBS twice", {
  
  chr = "chr8"
  pos = 67365913
  ref = "G"
  alt = "A"
  
  seq = get_sequence(chr, pos-20, pos+20, version = "hg19")
  pos_hits = single_sequence_coverage(seq, rel_pos = 21, pwm_list, min.score = "95%")
  
  expect_equal(length(pos_hits), 1) # de novo should hit a single PWM
  expect_equal(length(pos_hits[[1]]), 2) # there should be TWO different binding events (one + and one - strand) that result (see below)
  
  #>pos_hits
  #$MA0003.1
  #An object of class SiteSet with 2 site sequences
  #seqname source feature start end    score strand frame                                     attributes
  #1 ref_sequence   TFBS    TFBS    16  24 10.72269      +     . TF=TFAP2A;class=Zipper-Type;sequence=GCCCCGGGC
  #2 ref_sequence   TFBS    TFBS    16  24 10.82021      -     . TF=TFAP2A;class=Zipper-Type;sequence=GCCCGGGGC
  
})


test_that("gain of binding scan works", {
  
  seq = "GCTAATTCCACTATTTCTTCTCTTTTAATGAGATGAGCCTGTCCTCATCTT"
  rel_pos = 180462583 - 180462550 + 1  # relative position of de novo in sequence
  ref = substr(seq, rel_pos, rel_pos) # T
  alt = "C" # made up for test
  
  pwm_options = list("species" = 9606, "all_versions" = TRUE, "matrixtype" = "PWM") # 9606 = "homo sapiens"
  pwm_list = getMatrixSet(JASPAR2014, pwm_options)
  
  bc90 <- LOBGOB_scan(seq, rel_pos, ref, alt, pwm_list, min.score = "90%") # returns four events (all on ref)
  bc80 <- LOBGOB_scan(seq, rel_pos, ref, alt, pwm_list, min.score = "80%")  # will return lots of events
  
  expect_equal(sum(bc90$result == "LOSS"), 2)
  expect_equal(sum(bc90$result == "GAIN"), 0)
  expect_equal(sum(bc90$result == "SILENT"), 2)
  expect_equal(nrow(bc80), 23)

})