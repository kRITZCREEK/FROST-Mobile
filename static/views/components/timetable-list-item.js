import React from 'react';
import { formatBlock } from 'babel!./list-item-block';

var TimetableListItem = React.createClass({
  render() {
    let { topic: topic, block: block, room: room, onClick: handler } = this.props;
    return (
      <li className="collection-item" key={topic.description} >
        <div className="row">
          <div className="col s9">
            <h5>{topic.description}</h5>
            <div> {topic.typ + ' - ' + room.name} </div>
            <div> {formatBlock(block)} </div>
          </div>
          <div className="col s3">
            <p className="mdi-navigation-cancel clickable"
              style={{fontSize: '40px', color: '#ef5350', marginLeft: '-30px', paddingTop: '40px'}}
              onClick={handler}></p>
          </div>
        </div>
      </li>
    );
  }
});

export default TimetableListItem
