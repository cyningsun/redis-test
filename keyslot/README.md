### Syntax
``` bash
go run main.go key [key...]
```

## Example

``` bash
> go run main.go somekey
1) 11058
> go run main.go foo{hash_tag}
1) 2515
> go run main.go bar{hash_tag}
1) 2515
> go run main.go foo{hash_tag} bar{hash_tag}
1) 2515
2) 2515
```

Note that the command implements the full hashing algorithm, including support for **hash tags**, that is the special property of Redis Cluster key hashing algorithm, of hashing just what is between `{` and `}` if such a pattern is found inside the key name, in order to force multiple keys to be handled by the same node.