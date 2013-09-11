part of nv.shared;

class SelectionManager<E> extends _MappedListViewBase<E, Selectable<E>> {
  ObservableList<E> get source => super._source;

  int _selectedIndex = -1;

  SelectionManager(ObservableList<E> source) :
    super(source);

  E get selectedItem => hasSelection ? this[_selectedIndex].value : null;

  void set selectedItem(E value) {
    var index = _source.indexOf(value);
    selectedIndex = index;
  }

  int get selectedIndex => _selectedIndex;

  void set selectedIndex(int value) {
    assert(value != null);
    assert(value >= -1);
    assert(value < source.length);

    // TODO: if index has not changed?

    var oldSelection = hasSelection;
    if(oldSelection) {
      this[_selectedIndex]._updateIsSelectedValue(false);
    }

    if(value > -1) {
      _selectedIndex = value;
      this[_selectedIndex]._updateIsSelectedValue(true);
    }

    _notifyPropChange(const Symbol('selectedIndex'));
    _notifyPropChange(const Symbol('selectedItem'));
    if(oldSelection != hasSelection) {
      _notifyPropChange(const Symbol('hasSelection'));
    }
  }

  bool get hasSelection => _selectedIndex >= 0;

  //
  // Impl
  //

  Selectable<E> _wrap(E item) => new Selectable<E>._(item, this._requestSelect);

  void _requestSelect(Selectable<E> item, bool value) {
    throw new UnimplementedError('not impld');
  }
}

typedef void RequestSelect<E>(Selectable<E> item, bool requestedValue);

class Selectable<E> extends ChangeNotifierBase {
  final E value;
  final RequestSelect<E> _requestSelect;

  bool _isSelected = false;

  Selectable._(this.value, this._requestSelect);

  bool get isSelected => _isSelected;

  void set isSelected(bool value) {
    _requestSelect(this, value);
  }

  //
  // Implementation
  //

  /**
   * Called by the owning SelectionManager to actually change the selected value
   * and fire events
   */
  void _updateIsSelectedValue(bool value) {
    // generally, the caller should be smart enough to not do no-ops, right?
    assert(value != _isSelected);

    _isSelected = value;
    notifyPropertyChange(const Symbol('isSelected'), !value, value);
  }

}
