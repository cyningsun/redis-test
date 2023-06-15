package rebalance

// Link node
type LinkNode[T any] struct {
	Value      T
	Next, Prev *LinkNode[T]
}

type LinkList[T any] struct {
	Head, Tail *LinkNode[T]
}

func NewLinkList[T any]() *LinkList[T] {
	return &LinkList[T]{}
}

func (l *LinkList[T]) PushBack(v T) {
	node := &LinkNode[T]{Value: v}
	if l.Head == nil {
		l.Head = node
	} else {
		l.Tail.Next = node
		node.Prev = l.Tail
	}
	l.Tail = node
}

func (l *LinkList[T]) PushFront(v T) {
	node := &LinkNode[T]{Value: v}
	if l.Head == nil {
		l.Tail = node
	} else {
		l.Head.Prev = node
		node.Next = l.Head
	}
	l.Head = node
}

func (l *LinkList[T]) Iterator() *LinkIterator[T] {
	return &LinkIterator[T]{Current: l.Head}
}

func (l *LinkList[T]) Length() int {
	iter := l.Iterator()
	length := 0
	for iter.Next() {
		length++
	}
	return length
}

type LinkIterator[T any] struct {
	Current *LinkNode[T]
}

func (i *LinkIterator[T]) Next() bool {
	if i.Current == nil {
		return false
	}
	i.Current = i.Current.Next
	return true
}

func (i *LinkIterator[T]) Value() T {
	return i.Current.Value
}
