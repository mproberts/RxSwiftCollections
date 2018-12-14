//
//  ObservableList+UICollectionViewSections.swift
//  RxSwiftCollections
//
//  Created by Mike Roberts on 2018-10-10.
//
import RxSwift

private class SizingObservableListSectionedDataSource<S, T>: ObservableListSectionedDataSource<S, T>, UICollectionViewDelegateFlowLayout {
    
    fileprivate let cellSizer: ((IndexPath, T) -> CGSize)
    
    init(sections: Observable<Update<S>>,
         sectionTransformer: @escaping ((S) -> ObservableList<T>),
         cellCreator: @escaping ((UICollectionView, IndexPath, T) -> UICollectionViewCell),
         cellSizer: @escaping ((IndexPath, T) -> CGSize),
         valueSelected: @escaping ((T) -> Void)) {
        self.cellSizer = cellSizer
        
        super.init(sections: sections, sectionTransformer: sectionTransformer, cellCreator: cellCreator, valueSelected: valueSelected)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard collectionView.numberOfSections > indexPath.section else {
            return CGSize(width: 240.0, height: 240.0)
        }
        
        guard collectionView.numberOfItems(inSection: indexPath.section) > indexPath.row else {
            return CGSize(width: 240.0, height: 240.0)
        }
        
        // swiftlint:disable:next force_unwrapping
        let section = currentDataSources![indexPath.section]
        // swiftlint:disable:next force_unwrapping
        let item = section.currentList![indexPath.row]
        
        return cellSizer(indexPath, item)
    }
}

private class ObservableListSectionedDataSource<S, T>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
    
    fileprivate var currentDataSources: [ObservableListDataSource<T>]?
    fileprivate var currentSections: [S]?
    fileprivate var currentSubscriptions: [Disposable]?
    fileprivate let observableSections: Observable<Update<S>>
    fileprivate let cellCreator: ((UICollectionView, IndexPath, T) -> UICollectionViewCell)
    fileprivate let valueSelected: ((T) -> Void)
    
    fileprivate let sectionTransformer: ((S) -> ObservableList<T>)
    
    fileprivate var disposable: Disposable!
    
    init(sections: Observable<Update<S>>,
         sectionTransformer: @escaping ((S) -> ObservableList<T>),
         cellCreator: @escaping ((UICollectionView, IndexPath, T) -> UICollectionViewCell),
         valueSelected: @escaping ((T) -> Void)) {
        self.observableSections = sections
        self.sectionTransformer = sectionTransformer
        self.cellCreator = cellCreator
        self.valueSelected = valueSelected
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return currentSections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return currentDataSources?[section]
            .collectionView(collectionView, numberOfItemsInSection: section) ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // swiftlint:disable:next force_unwrapping
        let section = currentDataSources![indexPath.section]
        // swiftlint:disable:next force_unwrapping
        let item = section.currentList![indexPath.row]
        
        return cellCreator(collectionView, indexPath, item)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // swiftlint:disable:next force_unwrapping
        let section = currentDataSources![indexPath.section]
        // swiftlint:disable:next force_unwrapping
        let item = section.currentList![indexPath.row]
        
        valueSelected(item)
    }
    
    private func bind(to collectionView: UICollectionView, section: S, sectionIndex: Int) {
        let items = sectionTransformer(section)
        let dataSource = ObservableListDataSource(list: items.updates,
                                                  sectionIndex: sectionIndex,
                                                  cellCreator: cellCreator)
        
        currentDataSources?.insert(dataSource, at: sectionIndex)
        currentSubscriptions?.insert(dataSource.bind(to: collectionView), at: sectionIndex)
    }
    
    private func unbind(sectionIndex: Int) {
        let removed = currentSubscriptions?.remove(at: sectionIndex)
        
        currentDataSources?.remove(at: sectionIndex)
        
        removed?.dispose()
    }
    
    func bind(to collectionView: UICollectionView) -> Disposable {
        return self.observableSections
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (update) in
                guard let this = self else {
                    return
                }
                
                guard update.changes.first(where: { (change) -> Bool in
                    if case .reload = change {
                        return true
                    }
                    
                    return false
                }) == nil else {
                    if let subscriptions = this.currentSubscriptions {
                        for index in (0..<subscriptions.count).reversed() {
                            this.unbind(sectionIndex: index)
                        }
                    }
                    
                    this.currentSections = update.list.elements
                    this.currentSubscriptions = []
                    this.currentDataSources = []
                    
                    for sectionIndex in 0..<update.list.elements.count {
                        let section = update.list[sectionIndex]
                        
                        this.bind(to: collectionView, section: section, sectionIndex: sectionIndex)
                    }
                    collectionView.reloadData()
                    
                    return
                }
                
                collectionView.performBatchUpdates({
                    this.currentSections = update.list.elements
                    
                    update.changes.forEach { change in
                        switch change {
                        case .insert(let index):
                            for sectionIndex in index..<update.list.elements.count {
                                // swiftlint:disable:next force_unwrapping
                                let dataSource = this.currentDataSources![sectionIndex]
                                let section = update.list[sectionIndex]
                                
                                dataSource.sectionIndex += 1
                            }
                            
                            this.bind(to: collectionView, section: update.list[index], sectionIndex: index)
                            
                            collectionView.insertSections(IndexSet(integer: index))
                        case .delete(let index):
                            this.unbind(sectionIndex: index)
                            
                            collectionView.deleteSections(IndexSet(integer: index))
                        case .move(let from, let to):
                            // swiftlint:disable:next force_unwrapping
                            let dataSource = this.currentDataSources!.remove(at: from)
                            // swiftlint:disable:next force_unwrapping
                            let subscription = this.currentSubscriptions!.remove(at: from)
                            
                            dataSource.sectionIndex = to
                            
                            this.currentDataSources?.insert(dataSource, at: to)
                            this.currentSubscriptions?.insert(subscription, at: to)
                            
                            collectionView.moveSection(from, toSection: to)
                        case .reload:
                            break
                        }
                    }
                }, completion: { _ in })
                }, onError: { (_) in
            }, onCompleted: {
            })
    }
}

public extension ObservableList {
    
    func bindSections<S, CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                                         with adapter: @escaping ((UICollectionView, IndexPath, S) -> CellType),
                                                         sectionedBy sectionTransformer: @escaping ((T) -> ObservableList<S>),
                                                         valueSelected: @escaping ((S) -> Void) = { _ in }) -> Disposable {
        
        let dataSource = ObservableListSectionedDataSource(sections: self.updates,
                                                           sectionTransformer: sectionTransformer,
                                                           cellCreator: adapter,
                                                           valueSelected: valueSelected)
        let disposable = dataSource.bind(to: collectionView)
        
        collectionView.dataSource = dataSource
        
        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
    
    func bindSections<S, CellType: UICollectionViewCell>(to collectionView: UICollectionView,
                                                         with adapter: @escaping ((UICollectionView, IndexPath, S) ->   CellType),
                                                         sizedBy sizer: @escaping ((IndexPath, S) -> CGSize),
                                                         sectionedBy sectionTransformer: @escaping ((T) -> ObservableList<S>),
                                                         valueSelected: @escaping ((S) -> Void) = { _ in }) -> Disposable {
        let dataSource = SizingObservableListSectionedDataSource(sections: self.updates,
                                                                 sectionTransformer: sectionTransformer,
                                                                 cellCreator: adapter,
                                                                 cellSizer: sizer,
                                                                 valueSelected: valueSelected)
        let disposable = dataSource.bind(to: collectionView)
        
        collectionView.dataSource = dataSource
        collectionView.delegate = dataSource
        
        return AssociatedObjectDisposable(retaining: dataSource, disposing: disposable)
    }
}
