//
//  DifferentialObservableList.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-05-19.
//

import Foundation
import RxSwift
import DeepDiff

fileprivate class DifferentialObservableList<T: Hashable>: ObservableList<T> {
    private let stream: Observable<[T]>
    
    init(_ stream: Observable<[T]>) {
        self.stream = stream
    }
    
    override var updates: Observable<Update<T>> {
        get {
            return stream
                .map { (list: [T]) -> Update<T> in
                    return Update<T>(list: list, changes: [Change.reload])
                }
                .scan(Update(list: [], changes: [])) { (previous, next) -> Update<T> in
                    if (previous.changes.isEmpty) {
                        return Update(list: next.list, changes: [Change.reload])
                    }
                    
                    return Update(list: next.list, changes: DeepDiff.diff(old: previous.list, new: next.list)
                        .map { (change) -> Change in
                            switch (change) {
                            case .insert(let insert):
                                return Change.insert(index: insert.index)
                            case .delete(let delete):
                                return Change.delete(index: delete.index)
                            case .move(let move):
                                return Change.move(from: move.fromIndex, to: move.toIndex)
                            case .replace(let replace):
                                return Change.move(from: replace.index, to: replace.index)
                            }
                    })
            }
        }
    }
}

public extension ObservableList {
    static func diff<T: Hashable>(_ values: Observable<[T]>) -> ObservableList<T> {
        return DifferentialObservableList(values)
    }
}

