# Classify nodes from all matching environment Hiera files.
# Class parameters are then resolved by Puppet's automatic parameter lookup.
lookup('classes', Array[String[1]], 'unique', []).include
