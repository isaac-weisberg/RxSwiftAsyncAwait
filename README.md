RxSwift, except funni

HINDSIGHT: actors != locks, and the performance degradation from using them as such begins at 2x and can grow up to 100x.

This entire project is really useless.

## Big funny questions for the future:

**Q**: `await foo?.bar()` doesn't suspend never-ever, right?  
**A**: Shouldn't.

**Q**: `async let a = foo()` and then `async let b = bar()` don't release the actor in between them, never-ever, right?  
**A**: Not sure...

**Q**: `+arity`  versions of `combileLatest` and `zip` have been reimplemented be deferring to Collection versions because the originals were implented using inheritance and I was too lazy to reimplement without inheritance - it's okay? Do the collection-based versions perform worse than the old ones?  
**A**: Gotta check