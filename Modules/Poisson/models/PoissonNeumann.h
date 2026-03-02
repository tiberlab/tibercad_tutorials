/*  
 * This file is part of the tiberCAD module poisson.
 *
 * tiberCAD modules are licensed under the GNU General Public License v3.
 *
 * tiberCAD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * tiberCAD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with tiberCAD. If not, see <http://www.gnu.org/licenses/>.
 */

/*!
 * \file PoissonNeumann.h
 * \brief tiberCAD poisson module header.
 *
 * \note This file is part of module poisson.
 */


#ifndef TC_POISSONNEUMANN_H
#define TC_POISSONNEUMANN_H

#include "PoissonBoundaryModel.h"

#include "libmesh/point.h"
#include "libmesh/tensor_value.h"
#include "libmesh/vector_value.h"


class Elem;


//! The base class for Poisson boundary conditions
class PoissonNeumann : public PoissonBoundaryModel
{

  public:

    //! Destructor
    virtual ~PoissonNeumann(void) {};


    //! Calculate for a point on the given side
    virtual void calculate(const Elem* elem, unsigned int side,
        const Point& point) override;


  protected:

    //! Constructor
    PoissonNeumann(const ModelOptions& options);

    //! Initialize
    virtual void do_init(void) override;




  private:

    //! The normal field on the boundary
    double _field;

    unsigned int dim;
};



inline
PoissonNeumann::PoissonNeumann(const ModelOptions& options) :
  PoissonBoundaryModel(options),
  _field(0)
{
}



#endif // TC_POISSONNEUMANN_H
