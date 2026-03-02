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
 * \file PoissonBoundaryModel.h
 * \brief tiberCAD poisson module header.
 *
 * \note This file is part of module poisson.
 */


#ifndef TC_POISSONBOUNDARYMODEL_H
#define TC_POISSONBOUNDARYMODEL_H

#include "tibercad/physics/PhysicalModel.h"
#include "tibercad/module/SolutionProvider.h"


class Elem;
class Point;


//! The base class for Poisson boundary conditions
class PoissonBoundaryModel : public PhysicalModel
{

  public:

    //! Destructor
    ~PoissonBoundaryModel(void) {};

    //! Creator function
    static PoissonBoundaryModel* create(const MaterialBoundary* boundary,
        const ModelOptions& options);


    //! Calculate for a point on the given side
    virtual void calculate(const Elem* elem, unsigned int side,
        const Point& point) = 0;

    void get_coefficients(double& a, double& b, double& c);


  protected:

    //! Constructor
    PoissonBoundaryModel(const ModelOptions& options);

    void set_coefficients(double a, double b, double c);

    //! Simulation interface
    std::vector<SolutionProvider> _sim;

  private:

    double _alpha;
    double _beta;
    double _gamma;

};



inline
PoissonBoundaryModel::PoissonBoundaryModel(const ModelOptions& options) :
  PhysicalModel(options),
  _alpha(0),
  _beta(1),
  _gamma(0)
{
}



inline
void
PoissonBoundaryModel::get_coefficients(double& a, double& b, double& c)
{
  a = _alpha;
  b = _beta;
  c = _gamma;
}


inline
void
PoissonBoundaryModel::set_coefficients(double a, double b, double c)
{
  _alpha = a;
  _beta = b;
  _gamma = c;
}


#endif // TC_POISSONBOUNDARYMODEL_H
